#!/usr/bin/env python3
"""Article-desk wave contract tests, hermetic (same discipline as
test-dashboard-p1.py): real bound ThreadingHTTPServer on port 0 with
every filesystem touchpoint seamed into a tmp dir and both process
surfaces mocked (tmux via subprocess.run, the terminal via
subprocess.Popen). Covers GET /system/btop (fixed-size tmux capture,
idempotent spawn, 64KB cap) and POST /article/omp-session (token gate,
SESSION_RE id charset, newspaper.json package write, terminal spawn or
a visible 503). No real tmux, no real terminal, no real hngh home.
"""
import http.client
import importlib.util
import json
import os
import shutil
import tempfile
import threading
import time
import unittest
import unittest.mock
from pathlib import Path
from types import SimpleNamespace

ROOT = Path(__file__).resolve().parent.parent  # automation/


def _load(name, rel):
    spec = importlib.util.spec_from_file_location(
        name, str(ROOT.parent / "automation" / rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


ds = _load("dashboard_server", "dashboard-server.py")

ARTICLE = {
    "id": "abc12345",
    "category": "operator",
    "headline": "Head A",
    "deck": "Deck A",
    "body": ["line one", "line two"],
    "guidance": {"note_rules": "note <=200 chars",
                 "docs": [{"label": "Doc L", "path": "docs/design/x.md"}]},
}


class FakeTmux:
    """subprocess.run stand-in answering only the three tmux verbs the
    btop endpoint uses; anything else fails the test loudly."""

    def __init__(self, has_session_rc=(1, 0), capture=b"pane text"):
        self.calls = []
        self.has_session_rc = list(has_session_rc)
        self.capture = capture

    def __call__(self, argv, **kw):
        self.calls.append(list(argv))
        if argv[:2] == ["tmux", "has-session"]:
            rc = self.has_session_rc.pop(0) if self.has_session_rc else 0
            return SimpleNamespace(returncode=rc, stdout=b"", stderr=b"")
        if argv[:2] == ["tmux", "new-session"]:
            return SimpleNamespace(returncode=0, stdout=b"", stderr=b"")
        if argv[:2] == ["tmux", "capture-pane"]:
            return SimpleNamespace(returncode=0, stdout=self.capture,
                                   stderr=b"")
        raise AssertionError("unexpected subprocess call: %r" % (argv,))


class PopenRecorder:
    def __init__(self):
        self.calls = []

    def __call__(self, cmd, **kw):
        self.calls.append(list(cmd))
        return unittest.mock.MagicMock()


class ServerTest(unittest.TestCase):
    """Bound ThreadingHTTPServer, every touchpoint seamed into tmp."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        dash = self.tmp / "dashboard"
        dash.mkdir()
        (dash / "index.html").write_text(
            "<html><head><title>t</title></head><body></body></html>")
        (dash / "newspaper.json").write_text(json.dumps(
            {"articles": [ARTICLE], "edition": {}, "queues": {}}))
        ds.DASHBOARD = str(dash)
        ds.NEWSPAPER_JSON = str(dash / "newspaper.json")
        ds.TOKEN_FILE = str(dash / "token.txt")
        ds.HANDOFFS = str(self.tmp / "handoffs.md")
        self.reports = self.tmp / "reports.md"
        self.reports.write_text(
            "| ts | alert | deadbeef | unrelated first line | body |\n"
            "| ts | alert | row2 | mentions abc12345 here | body |\n")
        ds.REPORTS_MD = str(self.reports)
        self.home = self.tmp / "home"
        os.environ["HNGH_HOME_DIR"] = str(self.home)
        os.environ["DISPLAY"] = ":0"
        os.environ.pop("WAYLAND_DISPLAY", None)
        self.token = ds.load_token()
        self.httpd = ds.ThreadingHTTPServer(("127.0.0.1", 0), ds.Handler)
        threading.Thread(target=self.httpd.serve_forever,
                         daemon=True).start()
        self.port = self.httpd.server_address[1]

    def tearDown(self):
        self.httpd.shutdown()
        self.httpd.server_close()
        shutil.rmtree(self.tmp, ignore_errors=True)
        for k in ("HNGH_HOME_DIR", "DISPLAY", "WAYLAND_DISPLAY",
                  "HNGH_TERMINAL"):
            os.environ.pop(k, None)

    def post(self, payload, token="valid"):
        if token == "valid":
            token = self.token
        headers = {"Content-Type": "application/json", "Connection": "close"}
        if token is not None:
            headers["X-Hngh-Token"] = token
        c = http.client.HTTPConnection("127.0.0.1", self.port, timeout=10)
        c.request("POST", "/article/omp-session", json.dumps(payload),
                  headers)
        r = c.getresponse()
        data = r.read()
        c.close()
        return r.status, json.loads(data) if data else {}

    def get(self, path):
        c = http.client.HTTPConnection("127.0.0.1", self.port, timeout=10)
        c.request("GET", path, headers={"Connection": "close"})
        r = c.getresponse()
        data = r.read()
        ctype = r.headers.get("Content-Type")
        c.close()
        return r.status, ctype, data

    def package_path(self, aid="abc12345"):
        date = time.strftime("%Y-%m-%d", time.gmtime())
        return self.home / "dispatch" / date / (aid + ".context.md")


class BtopSnapshot(ServerTest):
    def test_snapshot_is_plain_text_and_spawns_session_idempotently(self):
        fake = FakeTmux(has_session_rc=(1, 0))
        with unittest.mock.patch.object(ds.subprocess, "run", fake):
            st, ctype, body = self.get("/system/btop")
            self.assertEqual(st, 200)
            self.assertIn("text/plain", ctype)
            self.assertEqual(body, b"pane text")
            spawns = [c for c in fake.calls
                      if c[:2] == ["tmux", "new-session"]]
            self.assertEqual(
                spawns[0],
                ["tmux", "new-session", "-d", "-x", "160", "-y", "48",
                 "-s", "hngh-btop", "btop -lt"])
            # second poll: session exists, no re-spawn
            st, ctype, body = self.get("/system/btop")
            self.assertEqual(st, 200)
            self.assertEqual(body, b"pane text")
            spawns = [c for c in fake.calls
                      if c[:2] == ["tmux", "new-session"]]
            self.assertEqual(len(spawns), 1)
            self.assertEqual(
                len([c for c in fake.calls
                     if c[:2] == ["tmux", "capture-pane"]]), 2)

    def test_snapshot_capped_near_64k(self):
        fake = FakeTmux(capture=b"x" * 100000)
        with unittest.mock.patch.object(ds.subprocess, "run", fake):
            st, ctype, body = self.get("/system/btop")
            self.assertEqual(st, 200)
            self.assertLessEqual(len(body), 65536)
            self.assertGreater(len(body), 60000)

    def test_tmux_failure_is_visible_not_fake_text(self):
        def boom(argv, **kw):
            raise OSError("no tmux binary")
        with unittest.mock.patch.object(ds.subprocess, "run", boom):
            st, ctype, body = self.get("/system/btop")
            self.assertEqual(st, 502)
            self.assertIn(b"btop capture failed", body)


class OmpSession(ServerTest):
    def test_token_gated(self):
        st, body = self.post({"id": "abc12345"}, token=None)
        self.assertEqual(st, 403)
        self.assertFalse(body.get("ok"))
        st, body = self.post({"id": "abc12345"}, token="0" * 32)
        self.assertEqual(st, 403)
        self.assertFalse(self.package_path().exists())

    def test_id_charset_colon_is_400(self):
        st, body = self.post({"id": "a:b"})
        self.assertEqual(st, 400)
        self.assertEqual(body.get("error"), "invalid id")
        st, body = self.post({"id": "../etc"})
        self.assertEqual(st, 400)
        self.assertFalse(self.package_path().exists())

    def test_invalid_json_400(self):
        st, body = self.post(["not", "an", "object"])
        self.assertEqual(st, 400)

    def test_unknown_article_404(self):
        st, body = self.post({"id": "zzzzzzzz"})
        self.assertEqual(st, 404)
        self.assertFalse(body.get("ok"))

    def test_writes_package_and_spawns_terminal(self):
        rec = PopenRecorder()
        with unittest.mock.patch.object(ds.subprocess, "Popen", rec), \
                unittest.mock.patch.object(
                    ds.shutil, "which",
                    lambda n: "/usr/bin/foot" if n == "foot" else None):
            st, body = self.post({"id": "abc12345"})
        self.assertEqual(st, 201)
        self.assertTrue(body.get("ok"))
        pkg = self.package_path()
        self.assertEqual(body.get("package"), str(pkg))
        self.assertTrue(pkg.is_file())
        md = pkg.read_text()
        for needle in ("Head A", "Deck A", "line one", "line two",
                       "note <=200 chars", "Doc L", "docs/design/x.md",
                       "mentions abc12345 here", "## Guidance",
                       str(pkg)):
            self.assertIn(needle, md)
        self.assertEqual(len(rec.calls), 1)
        cmd = rec.calls[0]
        self.assertEqual(cmd[0], "systemd-run")
        self.assertIn("--user", cmd)
        self.assertIn("--on-active=2", cmd)
        self.assertIn("foot", cmd)
        self.assertIn("bash", cmd)
        self.assertEqual(body.get("command"), cmd)

    def test_missing_display_503_fail_visible(self):
        rec = PopenRecorder()
        os.environ.pop("DISPLAY", None)
        with unittest.mock.patch.object(ds.subprocess, "Popen", rec):
            st, body = self.post({"id": "abc12345"})
        self.assertEqual(st, 503)
        self.assertFalse(body.get("ok"))
        self.assertIsInstance(body.get("command"), list)
        self.assertTrue(body.get("error"))
        self.assertEqual(rec.calls, [])
        # package still written: the operator can open it by hand
        self.assertTrue(self.package_path().is_file())

    def test_no_terminal_binary_503_fail_visible(self):
        rec = PopenRecorder()
        with unittest.mock.patch.object(ds.subprocess, "Popen", rec), \
                unittest.mock.patch.object(ds.shutil, "which",
                                           lambda n: None):
            st, body = self.post({"id": "abc12345"})
        self.assertEqual(st, 503)
        self.assertFalse(body.get("ok"))
        self.assertIn("terminal", body.get("error", ""))
        self.assertEqual(rec.calls, [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
