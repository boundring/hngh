#!/usr/bin/env python3
"""Dashboard P1 wave server contract tests, hermetic (review 2026-09-11 §5).

Real bound ThreadingHTTPServer on port 0 with every filesystem touchpoint
seamed into a tmp dir (same discipline as test-dashboard-feedback.py):
token guard (F3/plan step 6), session slicing, SSE push, telemetry feed,
and the report-queue mark-read wrapper. No real ledger, no real dashboard
files, no network beyond localhost.
"""
import http.client
import importlib.util
import json
import os
import socket
import sqlite3
import stat
import subprocess
import sys
import tempfile
import threading
import time
import unittest
import urllib.parse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # automation/


def _load(name, rel):
    spec = importlib.util.spec_from_file_location(
        name, str(ROOT.parent / "automation" / rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


ds = _load("dashboard_server", "dashboard-server.py")
ed = _load("email_digest", "scripts/email-digest.py")

STUB_RC = "HNGH_STUB_MARK_READ_RC"
STUB_LOG = "HNGH_STUB_MARK_READ_LOG"

STUB_REPORT_QUEUE = (
    "#!/usr/bin/env python3\n"
    "import os, sys\n"
    "with open(os.environ['HNGH_STUB_MARK_READ_LOG'], 'a') as f:\n"
    "    f.write(repr(sys.argv[1:]) + '\\n')\n"
    "sys.exit(int(os.environ.get('%s', '0')))\n" % STUB_RC
)


def sessions_fixture():
    entries = [{"n": n} for n in range(1, 8)]
    return {"generated": "2026-09-11T00:00:00Z", "sessions": [
        {"id": "run-a", "state": "done", "detail": {"entries": entries}},
        {"id": "run-b", "state": "done", "detail": {"tail": "no entries key"}}]}


def telemetry_fixture(db_path, now):
    conn = sqlite3.connect(str(db_path))
    conn.execute(
        "CREATE TABLE IF NOT EXISTS events(ts TEXT, source TEXT, kind TEXT,"
        " identity TEXT,"
        " lane TEXT, unit TEXT, model TEXT, tokens_in INTEGER, tokens_out"
        " INTEGER, cost_usd REAL, wall_s REAL, subject TEXT, refs TEXT,"
        " body TEXT)")
    conn.execute("DELETE FROM events")
    rows = [
        (time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now - 600)),
         "session-cost", "session", "m1", 100, 50, 0.02),
        (time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now - 4300)),
         "session-cost", "session", "m2", 10, 5, 0.25),
        (time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now - 2 * 86400)),
         "session-cost", "session", "m1", 9, 9, 9.0),
    ]
    conn.executemany(
        "INSERT INTO events(ts, source, kind, identity, lane, unit, model,"
        " tokens_in, tokens_out, cost_usd, wall_s, subject, refs, body)"
        " VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        [(r[0], r[1], r[2], None, None, None, r[3], r[4], r[5], r[6],
          None, None, None, None) for r in rows])
    conn.commit()
    conn.close()


class ServerTest(unittest.TestCase):
    """Bound ThreadingHTTPServer, every touchpoint seamed into tmp."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        dash = self.tmp / "dashboard"
        dash.mkdir()
        (dash / "index.html").write_text(
            "<html><head><title>t</title></head><body></body></html>")
        for name in ("operator-items.json", "operator-dismissed.json",
                     "readout.json"):
            (dash / name).write_text("{}")
        (dash / "sessions.json").write_text(json.dumps(sessions_fixture()))
        telemetry_fixture(dash / "telemetry.db", time.time())
        ds.DASHBOARD = str(dash)
        ds.TOKEN_FILE = str(dash / "token.txt")
        ds.SESSIONS_JSON = str(dash / "sessions.json")
        ds.TELEMETRY_DB = str(dash / "telemetry.db")
        ds.EVENT_WATCH = tuple(str(dash / n) for n in (
            "operator-items.json", "operator-dismissed.json", "readout.json"))
        ds.SSE_POLL_S = 0.1
        ds.SSE_HEARTBEAT_S = 1.0
        ds._tele_cache = (0.0, None)
        ds.HANDOFFS = str(self.tmp / "handoffs.md")
        stub = self.tmp / "stub-report-queue.py"
        stub.write_text(STUB_REPORT_QUEUE)
        ds.REPORT_QUEUE = str(stub)
        self.stub_log = str(self.tmp / "stub-calls.txt")
        os.environ[STUB_LOG] = self.stub_log
        self.token = ds.load_token()
        ds.Handler._fb_last = {}
        self.httpd = ds.ThreadingHTTPServer(("127.0.0.1", 0), ds.Handler)
        threading.Thread(target=self.httpd.serve_forever, daemon=True).start()
        self.port = self.httpd.server_address[1]

    def tearDown(self):
        self.httpd.shutdown()
        self.httpd.server_close()
        os.environ.pop(STUB_LOG, None)
        import shutil
        shutil.rmtree(self.tmp, ignore_errors=True)

    def post(self, path, payload, token="valid", ctype="application/json"):
        if token == "valid":
            token = self.token
        body = (json.dumps(payload) if ctype == "application/json"
                else urllib.parse.urlencode(payload))
        headers = {"Content-Type": ctype, "Connection": "close"}
        if token is not None:
            headers["X-Hngh-Token"] = token
        c = http.client.HTTPConnection("127.0.0.1", self.port, timeout=10)
        c.request("POST", path, body, headers)
        r = c.getresponse()
        data = r.read()
        c.close()
        return r.status, json.loads(data) if data else {}

    def get(self, path):
        c = http.client.HTTPConnection("127.0.0.1", self.port, timeout=10)
        c.request("GET", path, headers={"Connection": "close"})
        r = c.getresponse()
        data = r.read()
        c.close()
        return r.status, r.headers.get("Content-Type"), data


class TokenGuard(ServerTest):
    """Every POST requires X-Hngh-Token; wrong/missing -> 403 (F3)."""

    def test_403_without_wrong_with_right(self):
        self.assertEqual(self.post("/flag", {"session": "s", "note": "n"},
                                   token=None)[0], 403)
        self.assertEqual(self.post("/flag", {"session": "s", "note": "n"},
                                   token="0" * 32)[0], 403)
        st, body = self.post("/flag", {"session": "s", "note": "n"})
        self.assertEqual(st, 201)
        self.assertTrue(body["ok"])

    def test_403_precedes_404_dispatch(self):
        self.assertEqual(self.post("/no-such-route", {}, token="x")[0], 403)
        self.assertEqual(self.post("/no-such-route", {})[0], 404)

    def test_feedback_form_field_token(self):
        # email forms cannot carry headers: hidden hngh_token field instead
        st, _ = self.post("/api/feedback",
                          {"type": "idea", "text": "from email",
                           "hngh_token": self.token},
                          token=None, ctype="application/x-www-form-urlencoded")
        self.assertEqual(st, 201)
        # no header and no field -> fail closed
        st, _ = self.post("/api/feedback", {"type": "idea", "text": "x"},
                          token=None, ctype="application/x-www-form-urlencoded")
        self.assertEqual(st, 403)
        # a wrong header beats a right field: header is the primary channel
        st, _ = self.post("/api/feedback",
                          {"type": "idea", "text": "x",
                           "hngh_token": self.token},
                          token="0" * 32,
                          ctype="application/x-www-form-urlencoded")
        self.assertEqual(st, 403)

    def test_json_feedback_still_needs_header(self):
        st, _ = self.post("/api/feedback",
                          {"type": "idea", "text": "x", "hngh_token": self.token},
                          token=None)
        self.assertEqual(st, 403)


class TokenFile(ServerTest):
    """token.txt: 32-hex, mode 600, reused on later boots, fail closed."""

    def test_generated_32hex_mode_600(self):
        tok = ds.load_token()
        self.assertRegex(tok, r"^[0-9a-f]{32}$")
        mode = stat.S_IMODE(os.stat(ds.TOKEN_FILE).st_mode)
        self.assertEqual(mode, 0o600)

    def test_reuse_and_chmod_enforced(self):
        with open(ds.TOKEN_FILE, "w") as f:
            f.write("ab" * 16)
        os.chmod(ds.TOKEN_FILE, 0o644)
        self.assertEqual(ds.load_token(), "ab" * 16)
        mode = stat.S_IMODE(os.stat(ds.TOKEN_FILE).st_mode)
        self.assertEqual(mode, 0o600)

    def test_corrupt_token_regenerated(self):
        with open(ds.TOKEN_FILE, "w") as f:
            f.write("short")
        self.assertRegex(ds.load_token(), r"^[0-9a-f]{32}$")

    def test_index_html_injects_token_meta(self):
        st, ctype, data = self.get("/")
        self.assertEqual(st, 200)
        self.assertIn("text/html", ctype)
        self.assertIn(('<meta name="hngh-token" content="%s">' % self.token)
                      .encode(), data)


class SessionSlice(ServerTest):
    """GET /session/<id>?tail=N returns only the last N entries."""

    def get_json(self, path):
        st, _, data = self.get(path)
        return st, (json.loads(data) if data else {})

    def test_tail_slices_last_n(self):
        st, body = self.get_json("/session/run-a?tail=3")
        self.assertEqual(st, 200)
        self.assertEqual(body["id"], "run-a")
        self.assertEqual([e["n"] for e in body["entries"]], [5, 6, 7])

    def test_tail_clamped_1_200_default_20(self):
        _, body = self.get_json("/session/run-a?tail=999")
        self.assertEqual(len(body["entries"]), 7)  # clamped to what exists
        _, body = self.get_json("/session/run-a?tail=0")
        self.assertEqual(len(body["entries"]), 1)
        _, body = self.get_json("/session/run-a")
        self.assertEqual(len(body["entries"]), 7)  # default 20 > 7 present

    def test_unknown_and_invalid_ids_404(self):
        self.assertEqual(self.get("/session/never-was")[0], 404)
        self.assertEqual(self.get("/session/../../etc/passwd")[0], 404)
        self.assertEqual(self.get("/session/")[0], 404)

    def test_session_without_entries_returns_empty(self):
        st, body = self.get_json("/session/run-b")
        self.assertEqual(st, 200)
        self.assertEqual(body, {"id": "run-b", "entries": []})


class SsePush(ServerTest):
    """GET /events streams change events on mtime, heartbeats otherwise."""

    def _connect(self):
        s = socket.create_connection(("127.0.0.1", self.port), timeout=10)
        s.sendall(b"GET /events HTTP/1.1\r\nHost: t\r\n\r\n")
        return s

    def _read_until(self, s, marker, buf=b"", deadline=10.0):
        s.settimeout(0.5)
        end = time.time() + deadline
        while marker not in buf and time.time() < end:
            try:
                chunk = s.recv(4096)
                if not chunk:
                    break
                buf += chunk
            except socket.timeout:
                pass
        return buf

    def test_stream_headers_and_heartbeat(self):
        s = self._connect()
        buf = self._read_until(s, b": heartbeat")
        s.close()
        self.assertIn(b"200", buf.split(b"\r\n")[0])
        self.assertIn(b"text/event-stream", buf)
        self.assertIn(b": heartbeat", buf)

    def test_change_event_on_mtime_bump(self):
        s = self._connect()
        self._read_until(s, b": heartbeat")  # baseline mtimes recorded
        watched = self.tmp / "dashboard" / "operator-items.json"
        os.utime(str(watched), (time.time() + 5, time.time() + 5))
        buf = self._read_until(s, b"event: change")
        self.assertIn(b"event: change", buf)
        self.assertIn(b"operator-items.json", buf)
        s.close()


class TelemetryFeed(ServerTest):
    """GET /telemetry.json aggregates the last 24h of telemetry.db."""

    def setUp(self):
        super().setUp()
        self.now = time.time()
        self._teardown_db = ds.TELEMETRY_DB
        telemetry_fixture(ds.TELEMETRY_DB, self.now)
        ds._tele_cache = (0.0, None)

    def get_json(self):
        st, ctype, data = self.get("/telemetry.json")
        return st, ctype, (json.loads(data) if data else {})

    def test_numbers_match_fixture_db(self):
        st, ctype, body = self.get_json()
        self.assertEqual(st, 200)
        self.assertIn("application/json", ctype)
        self.assertEqual(body["window"], "24h")
        self.assertAlmostEqual(body["spend"], 0.27, places=6)
        self.assertEqual(body["legs"], {"m1": 1, "m2": 1})
        self.assertEqual(len(body["buckets"]), 2)
        by_hour = {b["hour"]: b for b in body["buckets"]}
        near = by_hour[time.strftime("%Y-%m-%dT%H",
                                     time.gmtime(self.now - 600))]
        self.assertEqual(near["runs"], 1)
        self.assertEqual(near["tokens_in"], 100)
        self.assertEqual(near["tokens_out"], 50)
        self.assertAlmostEqual(near["spend"], 0.02, places=6)
        # >24h-old row excluded
        self.assertAlmostEqual(sum(b["spend"] for b in body["buckets"]),
                               0.27, places=6)

    def test_30s_inprocess_cache(self):
        _, _, first = self.get_json()
        ds._tele_cache = (time.monotonic(), first)  # fresh cache entry
        conn = sqlite3.connect(ds.TELEMETRY_DB)
        conn.execute("UPDATE events SET cost_usd = 4.0 WHERE cost_usd = 0.02")
        conn.commit()
        conn.close()
        _, _, second = self.get_json()
        self.assertEqual(second, first)  # served from cache, not re-queried

    def test_missing_db_zeros(self):
        ds.TELEMETRY_DB = str(self.tmp / "nope.db")
        ds._tele_cache = (0.0, None)
        st, _, body = self.get_json()
        self.assertEqual(st, 200)
        self.assertEqual(body["spend"], 0)
        self.assertEqual(body["buckets"], [])


class MarkRead(ServerTest):
    """POST /report-queue/mark-read wraps scripts/report-queue --mark-read."""

    def test_calls_seamed_cli_and_logs_handoff(self):
        st, body = self.post("/report-queue/mark-read", {"id": "deadbeef"})
        self.assertEqual(st, 201)
        self.assertTrue(body["ok"])
        calls = open(self.stub_log).read().splitlines()
        self.assertEqual(calls, ["['--mark-read', 'deadbeef']"])
        handoffs = (self.tmp / "handoffs.md").read_text()
        self.assertIn("mark-read | ", handoffs)
        self.assertIn("automation|deadbeef | report marked read", handoffs)

    def test_bad_id_and_cli_refusal(self):
        self.assertEqual(self.post("/report-queue/mark-read",
                                   {"id": "bad id!"})[0], 400)
        os.environ[STUB_RC] = "2"
        try:
            st, body = self.post("/report-queue/mark-read", {"id": "unknown1"})
            self.assertEqual(st, 400)
            self.assertFalse(body["ok"])
        finally:
            del os.environ[STUB_RC]


class EmailFormToken(ServerTest):
    """Digest email form carries the token as a hidden field."""

    def test_form_has_hidden_token(self):
        html_form = ed.feedback_form_html(token="ab" * 16)
        self.assertIn('name="hngh_token"', html_form)
        self.assertIn('value="ab' + 'ab' * 15 + '"', html_form)

    def test_default_reads_token_file(self):
        ed.AUTOMATION = str(self.tmp)
        html_form = ed.feedback_form_html()
        self.assertIn('value="%s"' % self.token, html_form)


class JailEscapes(ServerTest):
    """Existing jails still fail closed on traversal."""

    def test_research_and_digest_traversal_404(self):
        self.assertEqual(self.get("/hngh-docs/research/..%2f..%2fx.md")[0], 404)
        self.assertEqual(self.get("/digest/..%2f..%2fsecret.md")[0], 404)


if __name__ == "__main__":
    unittest.main(verbosity=2)