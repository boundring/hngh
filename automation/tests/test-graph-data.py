#!/usr/bin/env python3
"""Graph-view fixture tests: graph-data.build() over seeded registries.

Hermetic: writes a tmp config/ + dashboard/ tree (leg-budgets, services,
packages, patrol-routes, cadence-params, research-lines, service-state.json,
reports.md) and a seeded telemetry db, then asserts node kinds, edges,
and live states the /graph.json endpoint serves. A second contract class
checks the dashboard-server route wiring textually (skipped on fresh
clones, same discipline as test-dashboard-p0).
"""

import importlib.util
import json
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
        "service-children\tservices\tservice-children\tday\tsvc-crumb\n")
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
                                      now=self.now)

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
        self.assertIn("vendor/three.min.js", html)


if __name__ == "__main__":
    unittest.main()
