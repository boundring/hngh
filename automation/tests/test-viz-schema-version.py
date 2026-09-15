#!/usr/bin/env python3
"""Version-gate acceptance tests for the viz payload schema validator.

Hermetic: no dashboard/ dependency, no network, no real registries. The
validator under test is the viz schema seam (automation/jobs/viz-schema.py
by default; _find_validator_module tolerates the seam's final name). Every
fail-closed rule is checked twice: once through the library API
(validate_payload -> issue list, ERROR items reject) and once through the
CLI (rc 0 valid / rc 2 failed closed), so callers can rely on exit codes.

Families under test (one fixture each, grounded in real emitters):
  graph/1  -- jobs/graph-data.py build(): {generated_at, nodes, edges};
              nodes carry id/kind/label/state/detail
  patrol/1 -- docs/design/ui-evolve/patrol-payload-schema.md section 1
  history/1 -- {'schema', 'entries': [{'key', 'ts', 'summary'}...]}, the
               shape pinned by the committed gate test-viz-schema-history.py

The unknown-extra-key WARN lane is scoped to ADDITIVE keys inside
nodes/edges/entries with scalar values; the envelope surface (top-level
keys) is the versioned surface, so an unknown top-level key fails closed.

Serialization discipline (the viz-docs-serialization lesson): every valid
fixture must survive json.loads(json.dumps(...)) and still validate.
"""

import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JOBS = ROOT / "jobs"

_VALIDATOR_CANDIDATES = ("viz-schema.py", "viz_schema.py", "schema.py")


def _find_validator_module():
    for name in _VALIDATOR_CANDIDATES:
        path = JOBS / name
        if path.exists():
            spec = importlib.util.spec_from_file_location(
                "viz_schema_under_test", path)
            mod = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(mod)
            return mod
    return None


VALIDATOR = _find_validator_module()

# --- CLI contract (single indirection point; a seam rename costs one line) --

VIZ_CLI_CANDIDATES = ("viz_schema.py", "viz-schema.py")
VIZ_CLI = next((JOBS / n for n in VIZ_CLI_CANDIDATES
                if (JOBS / n).exists()), JOBS / "viz_schema.py")


def _cli(tmp, tag, text):
    """Run the validator CLI over text; returns (rc, stdout+stderr)."""
    payload_path = Path(tmp) / "payload.json"
    payload_path.write_text(text)
    proc = subprocess.run(
        [sys.executable, str(VIZ_CLI), "--schema", tag, str(payload_path)],
        capture_output=True, text=True, timeout=30)
    return proc.returncode, proc.stdout + proc.stderr


# --- Library contract helpers ------------------------------------------

def _issues(payload, tag):
    return list(VALIDATOR.validate_payload(payload, tag))


def _errors(payload, tag):
    return [i for i in _issues(payload, tag)
            if i.get("severity") != "WARN"]


def _warns(payload, tag):
    return [i for i in _issues(payload, tag)
            if i.get("severity") == "WARN"]


def _detail_blob(payload, tag):
    return json.dumps(_issues(payload, tag))


# --- Payload family fixtures (current versions) --------------------------

_NOW = "2026-09-15T00:00:00Z"


def _graph_current():
    # Shape per jobs/graph-data.py build(): nodes carry id/kind/label/state,
    # edges carry src/dst/rel, top level is generated_at/nodes/edges.
    return {
        "schema": "graph/1",
        "generated_at": _NOW,
        "nodes": [
            {"id": "kernel", "kind": "kernel", "label": "hngh",
             "state": "healthy", "detail": "kernel spine"},
            {"id": "jcode:session_a", "kind": "jcode-session",
             "label": "worker", "state": "healthy", "detail": "worker"},
        ],
        "edges": [
            {"src": "jcode:session_a", "dst": "kernel", "rel": "works-on"},
        ],
    }


def _patrol_current():
    # Abridged from the design doc's worked example (all required fields).
    return {
        "schema": "patrol/1",
        "run_ts": _NOW,
        "date": "2026-09-15",
        "tier": "30m",
        "patrol_count": 1,
        "pass_count": 1,
        "fail_count": 1,
        "quip_present": True,
        "results": [
            {"id": "feeds", "surface": "dashboard-feeds",
             "check": "feed-freshness", "tier": "30m",
             "finding_class": "bad-execution",
             "passes": [{"name": "feed-freshness:plans.json",
                         "detail": "age=1343s"}],
             "fails": [{"artifact": "agent-handoffs.md",
                        "cause": "bad-execution",
                        "detail": "7 dead/cancelled in last 10 rows"}]},
        ],
        "rounds": [
            {"id": "feeds", "surface": "dashboard-feeds",
             "artifact": "agent-handoffs.md", "cause": "bad-execution"},
        ],
        "queued_subjects": [],
        "alerts": [
            {"identity": "patrol:feeds", "window": 86400,
             "text": "patrol feeds: bad-execution on agent-handoffs.md",
             "evidence": "7 dead/cancelled in last 10 rows"},
        ],
    }


def _history_current():
    # Shape pinned by the committed gate test-viz-schema-history.py:
    # {'schema': 'history/1', 'entries': [{'key', 'ts', 'summary'}...]}.
    return {
        "schema": "history/1",
        "entries": [
            {"key": "journal:2026-09-14", "ts": _NOW,
             "summary": "day note"},
            {"key": "gitlog:abc123", "ts": _NOW,
             "summary": "commit abc123 landed"},
        ],
    }


FAMILY_FIXTURES = {
    "graph/1": _graph_current,
    "patrol/1": _patrol_current,
    "history/1": _history_current,
}


@unittest.skipUnless(VALIDATOR is not None,
                     "viz schema validator module not present yet "
                     "(schema-validate-seam pending)")
class TestCurrentVersionAccepted(unittest.TestCase):
    """Each payload family accepts its own current version."""

    def test_each_family_accepts_current_version_library(self):
        for tag, fixture in FAMILY_FIXTURES.items():
            with self.subTest(tag=tag):
                self.assertEqual(_errors(fixture(), tag), [],
                                 "current version %s must validate clean"
                                 % tag)

    def test_each_family_accepts_current_version_cli(self):
        for tag, fixture in FAMILY_FIXTURES.items():
            with self.subTest(tag=tag):
                rc, out = _cli(self.enterContext(tempfile.TemporaryDirectory()),
                               tag, json.dumps(fixture()))
                self.assertEqual(rc, 0,
                                 "CLI must accept current %s (rc=%s, out=%s)"
                                 % (tag, rc, out))


@unittest.skipUnless(VALIDATOR is not None,
                     "viz schema validator module not present yet "
                     "(schema-validate-seam pending)")
class TestSchemaKeyFailClosed(unittest.TestCase):
    """The 'schema' key is the discriminator; anything off fails closed."""

    def _failing(self, mutate):
        for tag, fixture in FAMILY_FIXTURES.items():
            with self.subTest(tag=tag):
                payload = fixture()
                mutate(payload)
                issues = _errors(payload, tag)
                self.assertTrue(issues,
                                "mutated %s payload must fail closed" % tag)

    def test_missing_schema_key_fails_closed(self):
        self._failing(lambda p: p.pop("schema"))

    def test_missing_schema_key_auto_detect_fails_closed(self):
        # tag=None makes the validator rely on the payload's own schema
        # field; with it gone there is nothing to dispatch on.
        payload = _graph_current()
        payload.pop("schema")
        issues = VALIDATOR.validate_payload(payload)
        errors = [i for i in issues if i["severity"] != "WARN"]
        self.assertTrue(errors, "missing schema must fail closed")
        self.assertIn("schema", json.dumps(errors))

    def test_non_string_schema_value_fails_closed(self):
        for bad in (1, None, 1.5, ["graph/1"], {"v": "graph/1"}, True):
            with self.subTest(bad=bad):
                self._failing(lambda p, b=bad: p.__setitem__("schema", b))

    def test_non_string_schema_value_auto_detect_fails_closed(self):
        # tag=None reads the schema value itself; a non-string there must
        # be rejected, never coerced or matched loosely.
        for bad in (1, None, ["graph/1"], True):
            with self.subTest(bad=bad):
                payload = _graph_current()
                payload["schema"] = bad
                issues = VALIDATOR.validate_payload(payload)
                errors = [i for i in issues if i["severity"] != "WARN"]
                self.assertTrue(errors, "non-string schema %r must fail "
                                "closed" % (bad,))

    def test_unknown_future_version_fails_closed_mentioning_both(self):
        for tag, fixture in FAMILY_FIXTURES.items():
            if not tag.startswith("graph/"):
                continue
            with self.subTest(tag=tag):
                payload = fixture()
                future = "graph/99"
                payload["schema"] = future
                blob = _detail_blob(payload, tag)
                self.assertTrue(_errors(payload, tag),
                                "future version %s must fail closed" % future)
                self.assertIn(future, blob,
                              "detail must name the received version")
                self.assertIn(tag, blob,
                              "detail must name the expected version")

    def test_unknown_future_version_fails_closed_cli(self):
        tag = "graph/1"
        payload = _graph_current()
        payload["schema"] = "graph/99"
        rc, out = _cli(self.enterContext(tempfile.TemporaryDirectory()),
                       tag, json.dumps(payload))
        self.assertEqual(rc, 2, "CLI must fail closed with rc 2")
        self.assertIn("graph/99", out)
        self.assertIn("graph/1", out)


@unittest.skipUnless(VALIDATOR is not None,
                     "viz schema validator module not present yet "
                     "(schema-validate-seam pending)")
class TestCliFailClosedInputs(unittest.TestCase):
    """Bytes-level fail-closed behavior lives on the CLI only."""

    def test_malformed_json_fails_closed(self):
        rc, out = _cli(self.enterContext(tempfile.TemporaryDirectory()),
                       "graph/1", "{not json at all")
        self.assertEqual(rc, 2, "malformed JSON must fail closed (out=%s)"
                         % out)


@unittest.skipUnless(VALIDATOR is not None,
                     "viz schema validator module not present yet "
                     "(schema-validate-seam pending)")
class TestUnknownEnvelopeKeyFailClosed(unittest.TestCase):
    """The envelope surface is the versioned surface: an unknown top-level
    key means a future schema drifted into today's renderer; fail closed
    (the WARN lane is additive keys inside entries only)."""

    def test_unknown_envelope_key_fails_closed(self):
        for tag, fixture in FAMILY_FIXTURES.items():
            with self.subTest(tag=tag):
                payload = fixture()
                payload["__unknown_future_key"] = {"note": "forward-compat"}
                self.assertTrue(_errors(payload, tag),
                                "unknown envelope key must fail closed")


@unittest.skipUnless(VALIDATOR is not None,
                     "viz schema validator module not present yet "
                     "(schema-validate-seam pending)")
class TestUnknownExtraKeyWarnPath(unittest.TestCase):
    """Scalar extra keys inside entries warn but accept: the WARN lane."""

    # where an additive scalar key is tolerated per family
    _ENTRY = {
        "graph/1": lambda p: p["nodes"][0],
        "patrol/1": lambda p: p["results"][0],
        "history/1": lambda p: p["entries"][0],
    }

    def test_unknown_extra_key_accepts_with_warning_flag(self):
        for tag, fixture in FAMILY_FIXTURES.items():
            with self.subTest(tag=tag):
                payload = fixture()
                self._ENTRY[tag](payload)["__unknown_future_key"] = 1
                self.assertEqual(_errors(payload, tag), [],
                                 "WARN lane must accept the payload")
                warns = _warns(payload, tag)
                self.assertTrue(warns,
                                "WARN lane must flag the unknown key")

    def test_unknown_extra_key_cli_rc0_with_warning(self):
        payload = _graph_current()
        payload["nodes"][0]["__unknown_future_key"] = 1
        rc, out = _cli(self.enterContext(tempfile.TemporaryDirectory()),
                       "graph/1", json.dumps(payload))
        self.assertEqual(rc, 0, "WARN lane must not fail the CLI")
        self.assertIn("warn", out.lower(),
                      "CLI must surface the warning (out=%s)" % out)


@unittest.skipUnless(VALIDATOR is not None,
                     "viz schema validator module not present yet "
                     "(schema-validate-seam pending)")
class TestRcContractEndToEnd(unittest.TestCase):
    """Asserted once: callers can rely on validate -> rc 2."""

    def test_rc_contract(self):
        tmp = self.enterContext(tempfile.TemporaryDirectory())
        good = _cli(tmp, "graph/1", json.dumps(_graph_current()))[0]
        bad = _cli(tmp, "graph/1", json.dumps({"schema": "graph/1"}))[0]
        self.assertEqual(good, 0, "valid payload must exit 0")
        self.assertEqual(bad, 2, "fail-closed must exit exactly 2")
        self.assertNotIn(bad, (0, 1),
                         "rc 2 must be distinct from success and harness error")


@unittest.skipUnless(VALIDATOR is not None,
                     "viz schema validator module not present yet "
                     "(schema-validate-seam pending)")
class TestSerializationRoundTrip(unittest.TestCase):
    """viz-docs-serialization lesson: payloads survive JSON round-trip."""

    def test_round_tripped_payload_still_validates(self):
        for tag, fixture in FAMILY_FIXTURES.items():
            with self.subTest(tag=tag):
                payload = fixture()
                clone = json.loads(json.dumps(payload))
                self.assertEqual(clone, payload,
                                 "round-trip must be lossless for %s" % tag)
                self.assertEqual(_errors(clone, tag), [],
                                 "round-tripped %s must still validate" % tag)


if __name__ == "__main__":
    unittest.main()
