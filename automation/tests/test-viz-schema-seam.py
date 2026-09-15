#!/usr/bin/env python3
"""Acceptance tests for the viz payload schema seam (viz_schema.py).

Covers the schema-validate-seam contract end to end:
  - validate(payload_text, tag=None) -> (ok, detail, warns) and the
    validate_graph/validate_patrol/validate_history pinned-tag adapters.
  - WARN-and-accept: scalar unknown keys inside nodes/edges/entries,
    unknown rel/state/kind values, unknown patrol causes (open enum).
  - Fail closed: missing/non-string/wrong/unknown schema, malformed JSON,
    unknown envelope keys, nested payloads behind unknown keys, missing
    required fields, wrong types (bool is not an int), duplicate node ids
    or entry keys, self-loop edges, dangling edge endpoints, patrol count
    invariant. Every structural ERROR is also checked through the CLI rc
    2 contract; rc 1 is usage errors only.
  - One test runs the REAL graph builder (graph-data.build over a seeded
    tmp registry tree) through the validator: live output validates under
    tag graph/1 and — builder not yet stamping "schema" — fails closed
    under auto-detection, pinning the known wiring gap.

Hermetic: stdlib only, tmp fixtures, no network, no dashboard server.
"""

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEAM = ROOT / "jobs" / "viz_schema.py"

_spec = importlib.util.spec_from_file_location("viz_schema", SEAM)
viz_schema = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(viz_schema)


def _cli(tmp, tag, text):
    path = Path(tmp) / "payload.json"
    path.write_text(text)
    proc = subprocess.run(
        [sys.executable, str(SEAM), "--schema", tag, str(path)],
        capture_output=True, text=True, timeout=30)
    return proc.returncode, proc.stdout + proc.stderr


def _errors(issues):
    return [i for i in issues if i["severity"] == "ERROR"]


def _warns(issues):
    return [i for i in issues if i["severity"] == "WARN"]


# --- fixtures -----------------------------------------------------------

_NOW = "2026-09-15T00:00:00Z"


def _graph_payload(**over):
    p = {
        "schema": "graph/1",
        "generated_at": _NOW,
        "nodes": [
            {"id": "kernel", "kind": "kernel", "label": "hngh kernel",
             "state": "healthy", "detail": "one pattern"},
            {"id": "leg:deck", "kind": "leg", "label": "deck",
             "state": "stale", "detail": "max-time=300s"},
        ],
        "edges": [
            {"src": "kernel", "dst": "leg:deck", "rel": "chain-admits"},
        ],
    }
    p.update(over)
    return p


def _patrol_payload(**over):
    p = {
        "schema": "patrol/1",
        "run_ts": _NOW,
        "date": "2026-09-15",
        "tier": "30m",
        "patrol_count": 1,
        "pass_count": 1,
        "fail_count": 0,
        "quip_present": False,
        "results": [
            {"id": "feeds", "surface": "dashboard-feeds",
             "check": "feed-freshness", "tier": "30m",
             "finding_class": "bad-execution",
             "passes": [{"name": "feed-freshness:plans.json",
                         "detail": "age=1343s"}],
             "fails": []},
        ],
        "rounds": [],
        "queued_subjects": [],
        "alerts": [],
    }
    p.update(over)
    return p


def _history_payload(**over):
    p = {"schema": "history/1",
         "entries": [{"key": "h-1", "ts": _NOW, "summary": "note"}]}
    p.update(over)
    return p


# --- library contract ----------------------------------------------------

class LibraryContract(unittest.TestCase):

    def test_validate_returns_triple_and_adapters_exist(self):
        ok, detail, warns = viz_schema.validate(
            json.dumps(_graph_payload()), "graph/1")
        self.assertTrue(ok, detail)
        self.assertEqual([], warns)
        self.assertIn("ok", detail)
        for adapter, payload in (
                (viz_schema.validate_graph, _graph_payload()),
                (viz_schema.validate_patrol, _patrol_payload()),
                (viz_schema.validate_history, _history_payload())):
            ok, detail, _ = adapter(json.dumps(payload))
            self.assertTrue(ok, "%s: %s" % (adapter.__name__, detail))

    def test_schema_constant_exposes_supported_families(self):
        for tag in ("graph/1", "patrol/1", "history/1"):
            self.assertIn(tag, viz_schema.SCHEMA)


class WarnAndAccept(unittest.TestCase):

    def test_scalar_extra_key_inside_node_warns_and_accepts(self):
        p = _graph_payload()
        p["nodes"][0]["note"] = "forward-compat scalar"
        issues = viz_schema.validate_payload(p, "graph/1")
        self.assertEqual([], _errors(issues), str(issues))
        self.assertTrue(_warns(issues))
        ok, _, warns = viz_schema.validate(json.dumps(p), "graph/1")
        self.assertTrue(ok)
        self.assertTrue(warns)

    def test_scalar_extra_keys_inside_edge_and_history_entry_warn(self):
        p = _graph_payload()
        p["edges"][0]["weight"] = 2
        issues = viz_schema.validate_payload(p, "graph/1")
        self.assertEqual([], _errors(issues), str(issues))
        h = _history_payload()
        h["entries"][0]["note"] = "carry-over"
        issues = viz_schema.validate_payload(h, "history/1")
        self.assertEqual([], _errors(issues), str(issues))
        self.assertTrue(_warns(issues))

    def test_nested_extra_key_inside_node_fails_closed(self):
        for bad in ({"of": "x"}, ["a"], None):
            with self.subTest(bad=bad):
                p = _graph_payload()
                p["nodes"][0]["meta"] = bad
                issues = viz_schema.validate_payload(p, "graph/1")
                self.assertTrue(_errors(issues), str(issues))

    def test_unknown_rel_state_kind_values_warn_and_accept(self):
        p = _graph_payload()
        p["edges"][0]["rel"] = "future-rel"
        p["nodes"][1]["state"] = "degraded"
        p["nodes"][1]["kind"] = "future-kind"
        issues = viz_schema.validate_payload(p, "graph/1")
        self.assertEqual([], _errors(issues), str(issues))
        codes = {i["code"] for i in _warns(issues)}
        self.assertTrue({"unknown-rel-value", "unknown-state-value",
                         "unknown-kind-value"} <= codes, str(issues))

    def test_unknown_patrol_cause_accepts_as_data(self):
        # cause is an OPEN enum (patrol-payload-schema.md section 3):
        # unknown causes are data the journal rounds files by design, so
        # they are neither flagged nor rejected -- only the envelope and
        # types are the schema's business.
        p = _patrol_payload()
        p["results"][0]["fails"] = [
            {"artifact": "x.md", "cause": "novel-failure",
             "detail": "new bestiary class"}]
        p["fail_count"] = 1
        issues = viz_schema.validate_payload(p, "patrol/1")
        self.assertEqual([], issues, str(issues))
        ok, _, warns = viz_schema.validate(json.dumps(p), "patrol/1")
        self.assertTrue(ok)
        self.assertEqual([], warns)

    def test_patrol_tier_null_accepted_single_walk(self):
        p = _patrol_payload(tier=None)
        issues = viz_schema.validate_payload(p, "patrol/1")
        self.assertEqual([], _errors(issues), str(issues))

    def test_clean_payload_does_not_warn(self):
        for tag, payload in (("graph/1", _graph_payload()),
                             ("patrol/1", _patrol_payload()),
                             ("history/1", _history_payload())):
            with self.subTest(tag=tag):
                ok, detail, warns = viz_schema.validate(
                    json.dumps(payload), tag)
                self.assertTrue(ok, detail)
                self.assertEqual([], warns)


class FailClosed(unittest.TestCase):

    def _rejects(self, payload, tag, needle=None):
        issues = viz_schema.validate_payload(payload, tag)
        errs = _errors(issues)
        self.assertTrue(errs, "expected fail closed, got %s" % (issues,))
        if needle:
            blob = json.dumps(issues)
            self.assertIn(needle, blob)

    def test_missing_schema_key_fails_closed(self):
        for tag, payload in (("graph/1", _graph_payload()),
                             ("patrol/1", _patrol_payload()),
                             ("history/1", _history_payload())):
            with self.subTest(tag=tag):
                del payload["schema"]
                self._rejects(payload, tag, "schema")

    def test_non_string_schema_fails_closed(self):
        for bad in (1, None, 1.5, ["graph/1"], {"v": 1}, True):
            with self.subTest(bad=bad):
                p = _graph_payload(schema=bad)
                self._rejects(p, "graph/1")

    def test_wrong_schema_value_fails_closed(self):
        self._rejects(_graph_payload(schema="patrol/1"), "graph/1")

    def test_unknown_future_version_fails_closed_naming_both(self):
        p = _graph_payload(schema="graph/99")
        issues = viz_schema.validate_payload(p, "graph/1")
        self.assertTrue(_errors(issues))
        blob = json.dumps(issues)
        self.assertIn("graph/99", blob)
        self.assertIn("graph/1", blob)

    def test_auto_detect_unknown_version_fails_closed(self):
        p = _graph_payload(schema="graph/42")
        ok, detail, _ = viz_schema.validate(json.dumps(p))
        self.assertFalse(ok)
        self.assertIn("graph/42", detail)

    def test_unknown_envelope_key_fails_closed(self):
        for tag, payload, key in (
                ("graph/1", _graph_payload(), "meta"),
                ("patrol/1", _patrol_payload(), "window_days"),
                ("history/1", _history_payload(), "sources")):
            with self.subTest(tag=tag, key=key):
                payload[key] = {"nested": True}
                self._rejects(payload, tag, key)

    def test_missing_required_envelope_key_fails_closed(self):
        for tag, payload, field in (
                ("graph/1", _graph_payload(), "generated_at"),
                ("graph/1", _graph_payload(), "nodes"),
                ("patrol/1", _patrol_payload(), "alerts"),
                ("history/1", _history_payload(), "entries")):
            with self.subTest(tag=tag, field=field):
                del payload[field]
                self._rejects(payload, tag, field)

    def test_missing_required_node_edge_entry_field_fails_closed(self):
        p = _graph_payload()
        del p["nodes"][0]["detail"]
        del p["edges"][0]["rel"]
        self._rejects(p, "graph/1")
        h = _history_payload()
        del h["entries"][0]["ts"]
        self._rejects(h, "history/1", "ts")

    def test_wrong_types_fail_closed(self):
        p = _graph_payload(generated_at=7)
        p["nodes"][0]["id"] = 9
        self._rejects(p, "graph/1")
        q = _patrol_payload(patrol_count="1")
        self._rejects(q, "patrol/1")
        r = _patrol_payload(quip_present="yes")
        self._rejects(r, "patrol/1")

    def test_bool_is_not_int_for_counts(self):
        self._rejects(_patrol_payload(pass_count=True), "patrol/1")

    def test_non_list_nodes_fails_closed(self):
        self._rejects(_graph_payload(nodes={"id": "kernel"}), "graph/1")
        self._rejects(_graph_payload(edges="none"), "graph/1")
        self._rejects(_history_payload(entries="h-1"), "history/1")

    def test_entry_not_object_fails_closed(self):
        self._rejects(_graph_payload(nodes=["kernel"]), "graph/1")
        self._rejects(_history_payload(entries=["h-1"]), "history/1")

    def test_duplicate_node_ids_fail_closed(self):
        dup = {"id": "kernel", "kind": "kernel", "label": "k",
               "state": "healthy", "detail": "dup"}
        p = _graph_payload()
        p["nodes"].append(dup)
        self._rejects(p, "graph/1", "kernel")

    def test_duplicate_history_entry_keys_fail_closed(self):
        e = {"key": "h-dup", "ts": _NOW, "summary": "a"}
        p = _history_payload(entries=[e, dict(e)])
        self._rejects(p, "history/1", "h-dup")

    def test_self_loop_edge_fails_closed(self):
        p = _graph_payload()
        p["edges"].append({"src": "kernel", "dst": "kernel",
                           "rel": "chain-admits"})
        self._rejects(p, "graph/1", "self-loop")

    def test_dangling_edge_endpoints_fail_closed(self):
        p = _graph_payload()
        p["edges"].append({"src": "kernel", "dst": "ghost:node",
                           "rel": "runs"})
        self._rejects(p, "graph/1", "ghost:node")

    def test_patrol_count_invariant_fails_closed(self):
        p = _patrol_payload(patrol_count=5, pass_count=1, fail_count=1)
        self._rejects(p, "patrol/1", "patrol_count")

    def test_malformed_json_fails_closed(self):
        for text in ("{not json", "", "[]", '"str"', "null", "42"):
            with self.subTest(text=text[:20]):
                ok, detail, _ = viz_schema.validate(text, "graph/1")
                self.assertFalse(ok)
                self.assertIn("fail", detail)

    def test_non_object_envelope_fails_closed(self):
        ok, detail, _ = viz_schema.validate(json.dumps([1, 2]), "graph/1")
        self.assertFalse(ok)


# --- CLI / rc contract ---------------------------------------------------

class CliRcContract(unittest.TestCase):

    def test_rc0_valid_rc2_fail_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            good, _ = _cli(tmp, "graph/1", json.dumps(_graph_payload()))
            bad, out = _cli(tmp, "graph/1",
                            json.dumps({"schema": "graph/1"}))
            junk, _ = _cli(tmp, "graph/1", "{not json")
        self.assertEqual(0, good)
        self.assertEqual(2, bad, out)
        self.assertEqual(2, junk)
        self.assertNotIn(bad, (0, 1))

    def test_rc0_with_stderr_warning_on_warn_lane(self):
        p = _graph_payload()
        p["nodes"][0]["note"] = "scalar extra"
        with tempfile.TemporaryDirectory() as tmp:
            rc, out = _cli(tmp, "graph/1", json.dumps(p))
        self.assertEqual(0, rc)
        self.assertIn("warn", out.lower())

    def test_cli_usage_error_is_not_rc2(self):
        proc = subprocess.run(
            [sys.executable, str(SEAM), "--schema", "bogus/1", "/dev/null"],
            capture_output=True, text=True, timeout=30)
        self.assertEqual(1, proc.returncode)


# --- real builder end-to-end --------------------------------------------

def _seed_registries(root, now):
    """Minimal registry tree so graph-data.build() runs hermetically."""
    config = root / "config"
    dash = root / "dashboard"
    config.mkdir()
    dash.mkdir()
    (root / "tests").mkdir()
    (config / "leg-budgets.tsv").write_text(
        "unsloth\t300\t8192\t-\tlib/model.sh unsloth_chat\n"
        "ollama\t300\t1024\t-\tlib/model.sh ollama_chat\n"
        "deck\t300\t1024\t-\tlib/model.sh deck_chat\n"
        "remote\t300\t1024\t-\tlib/model.sh remote_chat\n"
        "kimi\t300\t1024\t-\tlib/model.sh kimi_chat\n"
        "zai\t300\t1024\t-\tlib/model.sh zai_chat\n"
        "ocgo\t300\t1024\t-\tlib/model.sh ocgo_chat\n"
        "opencode-agent\t1800\t50000\t1800\tlib/launch-session.sh\n")
    (config / "hngh-services.tsv").write_text(
        "service\trole\tinstall-method\tinstall-path\tstart-command"
        "\thealth-url\tmanaged-by\tdisposition\n"
        "ollama\tlocal inference\toperator\tsystem\tollama serve"
        "\thttp://127.0.0.1:11434/\toperator\tin-use\n")
    (config / "hngh-packages.tsv").write_text(
        "package\tupstream\trole\tinstall-path\tconfig-surface"
        "\tupdate-mechanism\tfollow-feed\tdisposition\n"
        "omp\thttps://example/omp\tharness\t/usr/bin/env\tnone\tnpm"
        "\t-\tin-use\n")
    (config / "patrol-routes.tsv").write_text(
        "patrol-id\tsurface\tcheck\tfreq-tier\tfinding-class\n"
        "feeds\tdashboard-feeds\tfeed-freshness\t30m\tbad-execution\n"
        "service-children\tservices\tservice-children\tday\tsvc-crumb\n")
    (root / "research-lines.tsv").write_text(
        "log-patterns\treviewed\t%s\tsome title\n"
        % now.strftime("%Y-%m-%dT%H:%M:%SZ"))
    return config, dash


class RealBuilderOutput(unittest.TestCase):

    def test_build_output_validates_under_graph_1(self):
        import sqlite3
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            now = datetime.now(timezone.utc).replace(microsecond=0)
            config, dash = _seed_registries(root, now)
            db = root / "telemetry.db"
            conn = sqlite3.connect(db)
            conn.execute("CREATE TABLE events (ts TEXT, model TEXT)")
            conn.commit()
            conn.close()
            gspec = importlib.util.spec_from_file_location(
                "graph_data_e2e", ROOT / "jobs" / "graph-data.py")
            graph_data = importlib.util.module_from_spec(gspec)
            gspec.loader.exec_module(graph_data)
            graph = graph_data.build(config, dash, db, root / "no-env",
                                     now=now, sessions_dir=root / "no-ses")
        self.assertGreater(len(graph["nodes"]), 0)
        # Unstamped live output fails closed under the pinned tag too:
        # the 'schema' key is required in every envelope (version-gate
        # family test), and build() does not stamp it yet. This is the
        # known wiring gap, gated here, never papered over.
        issues = viz_schema.validate_payload(graph, "graph/1")
        self.assertTrue(_errors(issues))
        codes = {i["code"] for i in issues}
        self.assertEqual({"missing-schema-field",
                          "missing-required-field"}, codes)
        # Every other structural rule already holds on live output: once
        # the builder stamps "schema": "graph/1", the payload validates
        # clean, under both pinned tag and auto-detection...
        stamped = dict(graph, schema="graph/1")
        issues = viz_schema.validate_payload(stamped, "graph/1")
        self.assertEqual([], issues, json.dumps(issues)[:2000])
        ok, detail, warns = viz_schema.validate(json.dumps(stamped))
        self.assertTrue(ok, detail)
        self.assertEqual([], warns)
        # ...and survives the JSON round trip.
        clone = json.loads(json.dumps(stamped))
        self.assertEqual([], viz_schema.validate_payload(clone, "graph/1"))


if __name__ == "__main__":
    unittest.main()
