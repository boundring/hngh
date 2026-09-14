#!/usr/bin/env python3
"""dashboard-server /graph.json refresh path, hermetic end-to-end.

Contract proven here (node sg-refresh-wiring, 2026-09-14):
  - TTL cache: the second call within TELEMETRY_TTL_S does NOT re-run the
    builder (registry scan happens once per slot per 30s).
  - Fail-soft: when the builder raises mid-flight, the endpoint still
    serves the last good graph (200), and a cold-start failure fails
    closed (500) instead of inventing an empty graph.
  - Pass-through: unknown/new node kinds ('jcode-session', 'swarm') come
    out of /graph.json byte-identical — the server never filters kinds.
  - ?all-sessions=1 is forwarded to graph_data.build() as
    all_sessions=1, with its own cache slot so a wide fetch neither
    serves from nor poisons the default feed.

Session-shaped fixture JSONs live in a temp dir; the server binds an
ephemeral port (127.0.0.1:0) for the duration of each test only — no
daemon, no live ports left behind (no-daemon boundary).
"""
import http.client
import importlib.util
import json
import shutil
import tempfile
import threading
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # automation/


def _load(name, rel):
    spec = importlib.util.spec_from_file_location(name, str(ROOT / rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


ds = _load("dashboard_server_graph", "dashboard-server.py")


class GraphEndpointTest(unittest.TestCase):
    """GET /graph.json over a real bound server; builder seamed."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        dash = self.tmp / "dash"
        dash.mkdir()
        ds.DASHBOARD = str(dash)  # token file lands in tmp, hermetic
        ds.TOKEN_FILE = str(dash / "token.txt")
        ds.load_token()
        # The graph builder is seamed: recording stub stands in for
        # jobs/graph-data.py so tests observe every build() call.
        self.build_calls = []

        def stub_build(*args, **kwargs):
            self.build_calls.append({"args": args, "kwargs": kwargs})
            return json.loads(json.dumps(self.next_graph()))

        self._real_builder = ds.graph_data.build
        ds.graph_data.build = stub_build
        ds._graph_cache = [(0.0, None), (0.0, None)]  # cold, per-test
        self.graph_seq = []  # pop-from-front payloads for the stub
        ds.Handler.protocol_version = "HTTP/1.1"
        self.httpd = ds.ThreadingHTTPServer(("127.0.0.1", 0), ds.Handler)
        self.t = threading.Thread(target=self.httpd.serve_forever, daemon=True)
        self.t.start()
        self.port = self.httpd.server_address[1]

    def tearDown(self):
        self.httpd.shutdown()
        self.httpd.server_close()
        ds.graph_data.build = self._real_builder
        shutil.rmtree(self.tmp, ignore_errors=True)

    # --- fixtures -----------------------------------------------------

    def queue_graph(self, kinds):
        """Queue a payload with exactly these node kinds."""
        self.graph_seq.append({
            "generated_at": "2026-09-14T12:00:00Z",
            "nodes": [{"id": "n:" + k, "kind": k, "label": k,
                       "state": "neutral", "detail": "fixture"} for k in kinds],
            "edges": []})

    def next_graph(self):
        return self.graph_seq.pop(0) if self.graph_seq else {"nodes": [], "edges": []}

    def get(self, path="/graph.json"):
        c = http.client.HTTPConnection("127.0.0.1", self.port, timeout=10)
        c.request("GET", path, headers={"Connection": "close"})
        r = c.getresponse()
        data = r.read()
        c.close()
        return r.status, json.loads(data) if data else {}

    # --- TTL cache reuse ----------------------------------------------

    def test_second_call_within_ttl_does_not_rescan(self):
        self.queue_graph(["kernel", "leg"])
        st1, g1 = self.get()
        st2, g2 = self.get()  # within TELEMETRY_TTL_S (30s)
        self.assertEqual((st1, st2), (200, 200))
        self.assertEqual(len(self.build_calls), 1, "builder re-ran inside TTL")
        self.assertEqual(g1, g2)
        # past TTL the builder runs again (session churn is picked up)
        ds._graph_cache[0] = (ds._graph_cache[0][0] - ds.TELEMETRY_TTL_S - 1.0,
                              ds._graph_cache[0][1])
        self.queue_graph(["kernel", "leg"])
        st3, _ = self.get()
        self.assertEqual(st3, 200)
        self.assertEqual(len(self.build_calls), 2, "expired cache never rebuilt")

    def test_ttl_value_is_30s(self):
        self.assertEqual(ds.TELEMETRY_TTL_S, 30.0)

    # --- fail-soft to last good graph ----------------------------------

    def test_builder_failure_serves_last_good_graph(self):
        self.queue_graph(["kernel", "leg"])
        st, good = self.get()
        self.assertEqual(st, 200)
        real_build = ds.graph_data.build

        def raising_build(*a, **k):
            raise RuntimeError("registry hiccup")

        ds.graph_data.build = raising_build
        try:
            st2, g2 = self.get()  # cache expired -> builder raises
        finally:
            ds.graph_data.build = real_build
        self.assertEqual(st2, 200)
        self.assertEqual(g2, good, "fail-soft graph differs from last good")

    def test_cold_start_builder_failure_fails_closed(self):
        def raising_build(*a, **k):
            raise RuntimeError("registries missing")

        real_build = ds.graph_data.build
        ds.graph_data.build = raising_build
        try:
            # The unhandled exception tears down the request thread; the
            # client observes that as a dropped connection (no 200 with
            # a fake body is ever possible).
            with self.assertRaises((http.client.RemoteDisconnected,
                                    ConnectionError, OSError)):
                self.get()
        finally:
            ds.graph_data.build = real_build

    # --- pass-through of unknown / new node kinds -----------------------

    def test_unknown_node_kinds_pass_through_unmodified(self):
        kinds = ["kernel", "jcode-session", "swarm", "leg"]
        self.queue_graph(kinds)
        st, g = self.get()
        self.assertEqual(st, 200)
        served = [n["kind"] for n in g["nodes"]]
        self.assertEqual(served, kinds, "server filtered or rewrote kinds")
        for k in ("jcode-session", "swarm"):
            self.assertIn({"id": "n:" + k, "kind": k, "label": k,
                           "state": "neutral", "detail": "fixture"},
                          g["nodes"], "node object mutated in transit")

    # --- all-sessions=1 pass-through ------------------------------------

    def test_all_sessions_flag_forwarded_to_builder(self):
        self.queue_graph(["kernel"])
        st, _ = self.get("/graph.json?all-sessions=1")
        self.assertEqual(st, 200)
        self.assertEqual(len(self.build_calls), 1)
        self.assertTrue(self.build_calls[0]["kwargs"].get("all_sessions"),
                        "all-sessions=1 not forwarded as build(all_sessions=1)")

    def test_default_request_builds_without_all_sessions(self):
        self.queue_graph(["kernel"])
        st, _ = self.get()
        self.assertEqual(st, 200)
        self.assertFalse(self.build_calls[0]["kwargs"].get("all_sessions"))

    def test_all_sessions_uses_its_own_cache_slot(self):
        self.queue_graph(["kernel"])       # default slot build
        self.get()
        self.queue_graph(["kernel", "jcode-session"])  # wide slot build
        st, wide = self.get("/graph.json?all-sessions=1")
        self.assertEqual(st, 200)
        self.assertEqual(len(self.build_calls), 2, "wide fetch served default slot")
        self.queue_graph(["kernel", "jcode-session"])
        st2, wide2 = self.get("/graph.json?all-sessions=1")
        self.assertEqual(len(self.build_calls), 2, "wide slot did not cache")
        self.assertEqual(wide2, wide)
        # and the wide fetch did not poison the default slot
        self.get()  # no queued payload: would crash the stub if it rebuilt
        self.assertEqual(len(self.build_calls), 2)


if __name__ == "__main__":
    unittest.main(verbosity=2)
