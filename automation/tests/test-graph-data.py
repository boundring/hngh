#!/usr/bin/env python3
"""Graph-view fixture tests: graph-data.build() over seeded registries.

Hermetic: writes a tmp config/ + dashboard/ tree (leg-budgets, services,
packages, patrol-routes, cadence-params, research-lines, service-state.json,
reports.md) and a seeded telemetry db, then asserts node kinds, edges,
and live states the /graph.json endpoint serves. A second contract class
checks the dashboard-server route wiring textually (skipped on fresh
clones, same discipline as test-dashboard-p0).

JcodeSessionNodes covers the jcode session/swarm node kinds over fixture
session files (id == filename stem, nanosecond ISO timestamps), including
state mapping, the malformed-JSON alerting decision, the 24h scale filter
with parent-link closure, and the all-sessions escape.
"""

import importlib.util
import json
import re
import sqlite3
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

_SPEC = importlib.util.spec_from_file_location(
    "graph_data", ROOT / "jobs" / "graph-data.py")
graph_data = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(graph_data)


def _ts(dt):
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def _seed(root, now):
    """Fixture registries + telemetry db; returns (config, dash, db)."""
    config = root / "config"
    dash = root / "dashboard"
    config.mkdir()
    dash.mkdir()
    (root / "tests").mkdir()
    (root / "config.env").write_text("REMOTE_DAILY_CAP_CALLS=200\n")
    (config / "leg-budgets.tsv").write_text(
        "# leg-budgets fixture (headerless, like the real registry)\n"
        "unsloth\t300\t8192\t-\tlib/model.sh unsloth_chat\n"
        "ollama\t300\t1024\t-\tlib/model.sh ollama_chat\n"
        "deck\t300\t1024\t-\tlib/model.sh deck_chat\n"
        "remote\t300\t1024\t-\tcap REMOTE_DAILY_CAP_CALLS=200/day, config.env:31\n"
        "kimi\t300\t1024\t-\tcap kimi-daily-cap 40/day, cadence-params.tsv:24\n"
        "zai\t300\t1024\t-\tcaps zai-cap-5h-calls rolling + zai-cap-week-calls week\n"
        "ocgo\t300\t1024\t-\tcaps opencode-cap-5h-calls 60/5h\n"
        "opencode-agent\t1800\t50000\t1800\tlib/launch-session.sh\n")
    # cadence-params.tsv lives at the automation root, not config/
    (root / "cadence-params.tsv").write_text(
        "# key\tvalue\tprovenance\tnote\n"
        "kimi-daily-cap\t40\tlib/model.sh\tmoonshot daily\n"
        "zai-cap-5h-calls\t60\tlib/model.sh\trolling\n"
        "zai-cap-week-calls\t300\tlib/model.sh\tweek\n")
    (config / "hngh-services.tsv").write_text(
        "service\trole\tinstall-method\tinstall-path\tstart-command"
        "\thealth-url\tmanaged-by\tdisposition\n"
        "ollama\tlocal inference\toperator\tsystem\tollama serve"
        "\thttp://127.0.0.1:11434/\toperator\tin-use\n"
        "llamacpp\tgguf server\tnone\t-\t-\t-\tnone\tavailable\n")
    (config / "hngh-packages.tsv").write_text(
        "package\tupstream\trole\tinstall-path\tconfig-surface"
        "\tupdate-mechanism\tfollow-feed\tdisposition\n"
        "omp\thttps://example/omp\tharness\t/usr/bin/env\tnone\tnpm\t-\tin-use\n"
        "ghost-pkg\thttps://example/g\tstudy\t/nonexistent/bin/g\t-\t-\t-\tin-use\n"
        "later-pkg\t-\t-\tnone-standalone (documented)\t-\t-\t-\tuse-later\n")
    (config / "patrol-routes.tsv").write_text(
        "patrol-id\tsurface\tcheck\tfreq-tier\tfinding-class\n"
        "budget\tbudget\tsession-budget\tday\tbudget-breach\n"
        "feeds\tdashboard-feeds\tfeed-freshness\t30m\tbad-execution\n"
        "service-children\tservices\tservice-children\tday\tsvc-crumb\n"
        # repeated surface: two patrols walk 'services', the surface
        # node must still be emitted exactly once (real patrol-routes
        # carries the same repetition: kernel-gate x2, services x2)
        "service-crumbs\tservices\tcrumb-scan\t30m\tsvc-crumb\n")
    (root / "research-lines.tsv").write_text(
        "log-patterns\treviewed\t%s\tsome title\n" % _ts(now))
    (root / "tests" / "test-credentials.py").write_text("# guard\n")
    (dash / "service-state.json").write_text(json.dumps({
        "generated": _ts(now),
        "units": [{"unit": "ollama.service", "active": True},
                  {"unit": "llama-server.service", "active": False}]}))
    (dash / "reports.md").write_text(
        "# Report ledger\n"
        "| %s | patrol-fail | patrol:budget | breach | b.md |\n"
        "| %s | patrol-fail | patrol:feeds | stale | f.md |\n"
        % (_ts(now - timedelta(hours=2)), _ts(now - timedelta(hours=40))))
    db = root / "telemetry.db"
    conn = sqlite3.connect(db)
    conn.execute("CREATE TABLE events (ts TEXT, source TEXT, kind TEXT,"
                 " identity TEXT, lane TEXT, unit TEXT, model TEXT,"
                 " tokens_in INTEGER, tokens_out INTEGER, cost_usd REAL,"
                 " wall_s REAL, subject TEXT, refs TEXT, body TEXT)")
    conn.executemany("INSERT INTO events (ts, model) VALUES (?, ?)", [
        (_ts(now - timedelta(minutes=30)), "unsloth/Qwen3-27B-GGUF"),
        (_ts(now - timedelta(hours=5)), "kimi:k3-256k"),
        (_ts(now - timedelta(hours=5)), "opencode-go/glm-5.3-flash"),
        (_ts(now - timedelta(days=3)), "z-ai/glm-5.3-flash")])
    conn.commit()
    conn.close()
    return config, dash, db


class BuildGraph(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        root = Path(self._tmp.name)
        self.now = datetime.now(timezone.utc).replace(microsecond=0)
        config, dash, db = _seed(root, self.now)
        self.graph = graph_data.build(config, dash, db, root / "config.env",
                                      now=self.now,
                                      sessions_dir=root / "no-sessions")

    def tearDown(self):
        self._tmp.cleanup()

    def _nodes(self, kind):
        return {n["id"]: n for n in self.graph["nodes"] if n["kind"] == kind}

    def _edges(self, rel=None, src=None, dst=None):
        return [e for e in self.graph["edges"]
                if (rel is None or e["rel"] == rel)
                and (src is None or e["src"] == src)
                and (dst is None or e["dst"] == dst)]

    def test_legs_admitted_with_budget_detail(self):
        legs = self._nodes("leg")
        self.assertIn("leg:unsloth", legs)
        self.assertIn("max-time=300s", legs["leg:unsloth"]["detail"])
        self.assertIn("max-output=8192", legs["leg:unsloth"]["detail"])
        self.assertTrue(self._edges(rel="chain-admits", dst="leg:unsloth"))

    def test_leg_live_state_from_telemetry(self):
        legs = self._nodes("leg")
        self.assertEqual(legs["leg:unsloth"]["state"], "healthy")
        self.assertEqual(legs["leg:kimi"]["state"], "stale")
        self.assertEqual(legs["leg:ocgo"]["state"], "stale")
        self.assertEqual(legs["leg:zai"]["state"], "neutral")
        self.assertEqual(legs["leg:remote"]["state"], "neutral")

    def test_caps_parsed_and_validated(self):
        caps = self._nodes("cap")
        self.assertEqual(caps["cap:REMOTE_DAILY_CAP_CALLS"]["state"], "healthy")
        self.assertEqual(caps["cap:kimi-daily-cap"]["state"], "healthy")
        self.assertEqual(caps["cap:zai-cap-5h-calls"]["state"], "healthy")
        self.assertEqual(caps["cap:opencode-cap-5h-calls"]["state"], "alerting")
        self.assertTrue(self._edges(src="cap:kimi-daily-cap", rel="bounded-by"))

    def test_services_from_units_and_watch_edge(self):
        svc = self._nodes("service")
        self.assertEqual(svc["service:ollama"]["state"], "healthy")
        self.assertEqual(svc["service:llamacpp"]["state"], "alerting")
        self.assertIn("http://127.0.0.1:11434/", svc["service:ollama"]["detail"])
        self.assertTrue(self._edges(src="service:ollama",
                                    dst="patrol:service-children",
                                    rel="watched-by"))

    def test_packages_ghost_and_none_exempt(self):
        pkgs = self._nodes("package")
        self.assertEqual(pkgs["package:omp"]["state"], "healthy")
        self.assertEqual(pkgs["package:ghost-pkg"]["state"], "alerting")
        self.assertEqual(pkgs["package:later-pkg"]["state"], "neutral")
        self.assertTrue(self._edges(dst="guard:test-hngh-packages.py"))

    def test_seams_bind_fail_soft_guards(self):
        seams = self._nodes("seam")
        self.assertIn("seam:op-cli", seams)
        self.assertTrue(self._edges(src="seam:op-cli",
                                    dst="guard:test-credentials.py",
                                    rel="fail-soft-guard"))
        self.assertTrue(self._edges(src="seam:notify-email",
                                    dst="guard:test-notify-seam.sh"))

    def test_guard_node_alerts_when_file_missing(self):
        guards = self._nodes("guard")
        self.assertEqual(guards["guard:test-credentials.py"]["state"], "healthy")
        self.assertEqual(guards["guard:test-doc-secrets.py"]["state"],
                         "alerting")

    def test_patrol_alerts_only_within_24h(self):
        pat = self._nodes("patrol")
        self.assertEqual(pat["patrol:budget"]["state"], "alerting")
        self.assertEqual(pat["patrol:feeds"]["state"], "healthy")
        self.assertTrue(self._edges(src="patrol:budget",
                                    dst="surface:budget", rel="watches"))

    def test_repeated_surface_node_emitted_once(self):
        # two patrols walk the same surface (fixture: service-children +
        # service-crumbs -> 'services'; real patrol-routes repeats
        # kernel-gate and services the same way): the surface node must
        # be emitted exactly once while each patrol still gets its own
        # watches edge (edges stay N:1).
        surfaces = self._nodes("surface")
        self.assertIn("surface:services", surfaces)
        services = [n for n in self.graph["nodes"]
                    if n["id"] == "surface:services"]
        self.assertEqual(len(services), 1,
                         "duplicate surface node emitted: %d copies"
                         % len(services))
        watchers = {e["src"] for e in self._edges(dst="surface:services",
                                                  rel="watches")}
        self.assertEqual(watchers, {"patrol:service-children",
                                    "patrol:service-crumbs"})
        # global invariants over the whole fixture feed: unique node
        # ids, no self-loop edges, no dangling edges.
        ids = [n["id"] for n in self.graph["nodes"]]
        self.assertEqual(len(ids), len(set(ids)),
                         "duplicate node ids: %s" % sorted(
                             i for i in ids if ids.count(i) > 1))
        node_ids = set(ids)
        for e in self.graph["edges"]:
            self.assertIn(e["src"], node_ids, str(e))
            self.assertIn(e["dst"], node_ids, str(e))
            self.assertNotEqual(e["src"], e["dst"], str(e))

    def test_no_dangling_edges_and_json_roundtrip(self):
        ids = {n["id"] for n in self.graph["nodes"]}
        for e in self.graph["edges"]:
            self.assertIn(e["src"], ids, str(e))
            self.assertIn(e["dst"], ids, str(e))
        json.dumps(self.graph)
        self.assertIn("kernel", ids)


class ServerWiring(unittest.TestCase):
    """Textual contract on the route glue (dashboard/ is gitignored
    machine data; skip when absent, like test-dashboard-p0)."""

    def setUp(self):
        if not (ROOT / "dashboard" / "index.html").is_file():
            raise unittest.SkipTest("dashboard/ not present")
        self.server = (ROOT / "dashboard-server.py").read_text()

    def test_graph_route_registered(self):
        self.assertIn('route == "/graph.json"', self.server)
        self.assertIn("graph_data.build", self.server)

    def test_view_registered_in_shell(self):
        html = (ROOT / "dashboard" / "index.html").read_text()
        self.assertIn("graph-view.js", html)
        self.assertIn('data-tab="graph"', html)

    def test_no_duplicate_element_ids(self):
        # HTML id uniqueness is a hard DOM contract (getElementById and
        # querySelector behavior change under duplicates). The 2026-09-14
        # refresh-button wiring accidentally shipped two byte-identical
        # <button id="refresh-btn">; the dup was removed, and this guards
        # the whole shell against a repeat. Single refresh button is the
        # deliberate design: one, asserted exactly here.
        html = (ROOT / "dashboard" / "index.html").read_text()
        seen = {}
        for i in re.finditer(r'\bid="([^"]+)"', html):
            seen[i.group(1)] = seen.get(i.group(1), 0) + 1
        dups = sorted(k for k, v in seen.items() if v > 1)
        self.assertEqual(dups, [],
                         "duplicate element ids in index.html: %s" % dups)
        self.assertEqual(html.count('id="refresh-btn"'), 1)


def _session(mid, short_name=None, status="Active", model="glm-5.3-flash",
             provider="openai-compatible:zai", cwd="/home/u/proj",
             age_min=5, pid=1234, effort="high", parent_id=None):
    """Fixture session json dict with nanosecond-precision timestamps."""
    ts = (datetime.now(timezone.utc) - timedelta(minutes=age_min))
    # nanosecond fraction, like the real jcode files (9 digits)
    stamp = ts.strftime("%Y-%m-%dT%H:%M:%S") + ".123456789Z"
    d = {"id": "session_%s_1789413055609_deadbeefcafe" % mid,
         "created_at": stamp, "updated_at": stamp,
         "last_active_at": stamp, "status": status, "model": model,
         "provider_key": provider, "working_dir": cwd, "last_pid": pid,
         "parent_id": parent_id, "title": "t %s" % mid}
    if short_name is not None:
        d["short_name"] = short_name
    if effort is not None:
        d["reasoning_effort"] = effort
    return d


class JcodeSessionNodes(unittest.TestCase):
    """Session/swarm nodes over fixture files in a fake ~/.jcode/sessions."""

    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        root = Path(self._tmp.name)
        self.now = datetime.now(timezone.utc).replace(microsecond=0)
        self.sessions = root / "sessions"
        self.sessions.mkdir()
        config, dash, db = _seed(root, self.now)
        self.root, self.config, self.dash, self.db = root, config, dash, db

    def tearDown(self):
        self._tmp.cleanup()

    def write(self, name, data):
        (self.sessions / name).write_text(
            data if isinstance(data, str) else json.dumps(data))

    def build(self, **kw):
        return graph_data.build(self.config, self.dash, self.db,
                                self.root / "config.env", now=self.now,
                                sessions_dir=self.sessions, **kw)

    def sess(self, graph, sid):
        for n in graph["nodes"]:
            if n["id"] == "jcode:" + sid:
                return n
        self.fail("no node jcode:" + sid)

    def test_session_nodes_with_detail_and_edges(self):
        par = _session("p", short_name="coord", age_min=2)
        sub = _session("sub1", short_name="worker", parent_id=par["id"])
        self.write(par["id"] + ".json", par)
        self.write(sub["id"] + ".json", sub)
        # non-session files and backup copies must be skipped entirely
        self.write("session_x_1_skipme.journal.jsonl", {"id": "x"})
        self.write(par["id"] + ".json.bak", {"id": "bak"})
        g = self.build()
        kinds = {n["id"]: n["kind"] for n in g["nodes"]}
        self.assertEqual(kinds["jcode:" + par["id"]], "jcode-session")
        self.assertEqual(kinds["jcode:" + sub["id"]], "jcode-session")
        self.assertNotIn("jcode:x", kinds)
        self.assertNotIn("jcode:bak", kinds)
        coord, worker = self.sess(g, par["id"]), self.sess(g, sub["id"])
        self.assertEqual(worker["label"], "worker")
        self.assertEqual(coord["label"], "coord")
        for key, val in (("status", "Active"), ("model", "glm-5.3-flash"),
                         ("provider", "openai-compatible:zai"),
                         ("cwd", "/home/u/proj"), ("pid", 1234),
                         ("effort", "high")):
            self.assertIn("%s=%s" % (key, val), worker["detail"])
        self.assertIn("age=", worker["detail"])
        self.assertTrue(any(e == {"src": "jcode:" + par["id"],
                                  "dst": "jcode:" + sub["id"],
                                  "rel": "spawns"} for e in g["edges"]))

    def test_label_falls_back_to_truncated_id(self):
        s = _session("lbl")  # short_name omitted by default
        self.write(s["id"] + ".json", s)
        node = self.sess(self.build(), s["id"])
        self.assertEqual(node["label"], s["id"][:12])

    def test_state_mapping_four_states(self):
        a = _session("a", age_min=5)
        b = _session("b", age_min=30)
        c = _session("c", status="Closed")
        for s in (a, b, c):
            self.write(s["id"] + ".json", s)
        g = self.build()
        self.assertEqual(self.sess(g, a["id"])["state"], "healthy")
        self.assertEqual(self.sess(g, b["id"])["state"], "stale")
        self.assertEqual(self.sess(g, c["id"])["state"], "neutral")

    def test_malformed_json_emits_alerting_node(self):
        self.write("session_bad_1_b.json", "{not json")
        good = _session("good")
        self.write(good["id"] + ".json", good)
        g = self.build()
        bad = self.sess(g, "session_bad_1_b")
        self.assertEqual(bad["state"], "alerting")
        self.assertIn("malformed", bad["detail"])
        self.assertEqual(self.sess(g, good["id"])["state"], "healthy")

    def test_swarm_hub_edges_only_when_subagents(self):
        par = _session("par", short_name="hub")
        s1 = _session("s1", parent_id=par["id"])
        s2 = _session("s2", parent_id=par["id"])
        lone = _session("lone")
        for s in (par, s1, s2, lone):
            self.write(s["id"] + ".json", s)
        g = self.build()
        kinds = {n["id"]: n["kind"] for n in g["nodes"]}
        self.assertEqual(kinds["swarm:" + par["id"]], "swarm")
        self.assertNotIn("swarm:" + lone["id"], kinds)
        rels = {(e["src"], e["dst"], e["rel"]) for e in g["edges"]}
        cid = "swarm:" + par["id"]
        self.assertIn((cid, "jcode:" + par["id"], "coordinates"), rels)
        self.assertIn((cid, "jcode:" + s1["id"], "hosts"), rels)
        self.assertIn((cid, "jcode:" + s2["id"], "hosts"), rels)

    def test_works_on_edge_inside_hngh_repo(self):
        # fixture repo-root analog is self.root.parent (config/ sits at
        # <automation>/config in the real tree); subdir cwd also counts
        inside = _session("in", cwd=str(self.root.parent))
        subin = _session("subin", cwd=str(self.root / "jobs"))
        outside = _session("out", cwd="/home/u/other")
        for s in (inside, subin, outside):
            self.write(s["id"] + ".json", s)
        g = self.build()
        rels = {(e["src"], e["rel"]) for e in g["edges"]}
        self.assertIn(("jcode:" + inside["id"], "works-on"), rels)
        self.assertIn(("jcode:" + subin["id"], "works-on"), rels)
        self.assertNotIn(("jcode:" + outside["id"], "works-on"), rels)

    def test_scale_filter_24h_plus_parent_closure(self):
        recent = _session("rec", age_min=60)
        old = _session("old", age_min=60 * 30)
        # old coordinator kept alive by a recent sub (upward closure)
        pold = _session("pold", age_min=60 * 30)
        crec = _session("crec", age_min=60, parent_id=pold["id"])
        # recent coordinator drags its old chain in (downward, transitively)
        rc = _session("rc", age_min=60)
        mid = _session("mid", age_min=60 * 30, parent_id=rc["id"])
        leaf = _session("leaf", age_min=60 * 30, parent_id=mid["id"])
        for s in (recent, old, pold, crec, rc, mid, leaf):
            self.write(s["id"] + ".json", s)
        ids = {n["id"] for n in self.build()["nodes"]}
        self.assertIn("jcode:" + recent["id"], ids)
        self.assertNotIn("jcode:" + old["id"], ids)  # no anchor: stays out
        self.assertIn("jcode:" + crec["id"], ids)
        self.assertIn("jcode:" + pold["id"], ids)  # recent sub keeps coord
        self.assertIn("jcode:" + mid["id"], ids)
        self.assertIn("jcode:" + leaf["id"], ids)  # transitive drag-in
        # escape hatch: all_sessions=True emits the stale session too
        ids_all = {n["id"] for n in self.build(all_sessions=True)["nodes"]}
        self.assertIn("jcode:" + old["id"], ids_all)

    def test_sessions_dir_absent_is_noop(self):
        g = graph_data.build(self.config, self.dash, self.db,
                             self.root / "config.env", now=self.now,
                             sessions_dir=self.root / "missing")
        self.assertFalse([n for n in g["nodes"]
                          if n["kind"] in ("jcode-session", "swarm")])

    def test_duplicate_internal_id_surfaces_shadowed_file(self):
        # coordinator + child mapping to the same run (two files, one
        # internal id): the winner keeps the jcode: id, the shadowed file
        # surfaces as an alerting node under its own stem, and no
        # self-loop spawns edge is emitted.
        stamp = self.now.strftime("%Y-%m-%dT%H:%M:%S") + ".123456789Z"
        coord = {"id": "session_samerun_1_deadbeefcafe",
                 "last_active_at": stamp, "updated_at": stamp,
                 "status": "Active", "short_name": "coord"}
        child = {"id": "session_samerun_1_deadbeefcafe",
                 "last_active_at": stamp, "updated_at": stamp,
                 "status": "Active", "short_name": "child",
                 "parent_id": "session_samerun_1_deadbeefcafe"}
        self.write("session_samerun_1_deadbeefcafe.json", coord)
        self.write("session_samerun_2_0123456789ab.json", child)
        g = self.build(all_sessions=True)
        ids = [n["id"] for n in g["nodes"]]
        self.assertEqual(len(ids), len(set(ids)),
                         "duplicate node ids: %s" % sorted(ids))
        by_id = {n["id"]: n for n in g["nodes"]}
        self.assertIn("jcode:session_samerun_1_deadbeefcafe", by_id)
        shadow = by_id["jcode:session_samerun_2_0123456789ab"]
        self.assertEqual(shadow["kind"], "jcode-session")
        self.assertEqual(shadow["state"], "alerting")
        self.assertIn("duplicate", shadow["detail"])
        for e in g["edges"]:
            self.assertNotEqual(e["src"], e["dst"],
                                "self-loop edge: %s" % (e,))

    def test_node_ids_unique_end_to_end(self):
        # global invariant over a mixed fixture: never two nodes share
        # an id, and never a self-loop edge.
        par = _session("p", short_name="coord", age_min=2)
        sub = _session("sub1", short_name="worker", parent_id=par["id"])
        self.write(par["id"] + ".json", par)
        self.write(sub["id"] + ".json", sub)
        self.write("session_bad_1_b.json", "{not json")
        g = self.build(all_sessions=True)
        ids = [n["id"] for n in g["nodes"]]
        self.assertEqual(len(ids), len(set(ids)),
                         "duplicate node ids: %s" % sorted(ids))
        node_ids = set(ids)
        for e in g["edges"]:
            self.assertIn(e["src"], node_ids, str(e))
            self.assertIn(e["dst"], node_ids, str(e))
            self.assertNotEqual(e["src"], e["dst"], str(e))


if __name__ == "__main__":
    unittest.main()
