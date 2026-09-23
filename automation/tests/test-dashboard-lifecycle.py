#!/usr/bin/env python3
"""Stage-2 exit gate: the operator-item lifecycle endpoints.

POST /operator-item/handle and POST /operator-item/dismiss record the
open -> handled / open -> dismissed transitions in their ledgers
(dashboard/operator-approved.json / operator-dismissed.json,
{"approved"|"dismissed": {"<id>": "<UTC ts>"}}, atomic replace) and
each transition files exactly ONE report-queue progress row (identity
operator-item:<id>:<state>). Repeat posts are idempotent: no second
row. A report-queue failure fails the POST closed with the ledger
untouched, so no transition ever lands silently without its row. The
token guard covers both endpoints.

Run: python3 automation/tests/test-dashboard-lifecycle.py
"""
import importlib.util
import json
import os
import sys
import tempfile
import threading
import unittest
import urllib.error
import urllib.request
from pathlib import Path

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # automation/

STUB_RQ = r'''
import os, sys
with open(os.environ["HNGH_STUB_RQ_LOG"], "a") as f:
    f.write(repr(sys.argv[1:]) + "\n")
raise SystemExit(int(os.environ.get("HNGH_STUB_RQ_RC", "0")))
'''


def _load():
    spec = importlib.util.spec_from_file_location(
        "ds_lifecycle", os.path.join(ROOT, "dashboard-server.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


ds = _load()


class Lifecycle(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        base = Path(self.tmp.name)
        dash = base / "dashboard"
        dash.mkdir()
        (dash / "index.html").write_text(
            "<html><head><title>t</title></head><body></body></html>")
        for name in ("operator-items.json", "operator-dismissed.json",
                     "readout.json"):
            (dash / name).write_text("{}")
        self.approved = dash / "operator-approved.json"
        self.dismissed = dash / "operator-dismissed.json"
        self.handoffs = base / "agent-handoffs.md"
        self.rq_log = base / "rq.log"
        stub = base / "stub-report-queue"
        stub.write_text(STUB_RQ)
        stub.chmod(0o755)
        ds.TOKEN_FILE = str(base / "token.txt")
        ds.HANDOFFS = str(self.handoffs)
        ds.DISMISSED = str(self.dismissed)
        ds.APPROVED = str(self.approved)
        ds.REPORT_QUEUE = str(stub)
        ds.EVENT_WATCH = tuple(str(dash / n) for n in (
            "operator-items.json", "operator-dismissed.json",
            "operator-approved.json", "readout.json"))
        self.old_env = {k: os.environ.get(k)
                        for k in ("HNGH_STUB_RQ_LOG", "HNGH_STUB_RQ_RC")}
        os.environ["HNGH_STUB_RQ_LOG"] = str(self.rq_log)
        os.environ.pop("HNGH_STUB_RQ_RC", None)
        self.token = ds.load_token()
        self.httpd = ds.ThreadingHTTPServer(("127.0.0.1", 0), ds.Handler)
        self.port = self.httpd.server_address[1]
        threading.Thread(target=self.httpd.serve_forever,
                         daemon=True).start()
        self.addCleanup(self._teardown)

    def _teardown(self):
        self.httpd.shutdown()
        self.httpd.server_close()
        for key, val in self.old_env.items():
            if val is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = val
        self.tmp.cleanup()

    def post(self, route, obj, token=True):
        req = urllib.request.Request(
            "http://127.0.0.1:%d/%s" % (self.port, route),
            data=json.dumps(obj).encode(),
            headers={"Content-Type": "application/json"})
        if token:
            req.add_header("X-Hngh-Token", self.token)
        try:
            with urllib.request.urlopen(req, timeout=5) as r:
                return r.status, json.loads(r.read() or b"{}")
        except urllib.error.HTTPError as e:
            return e.code, json.loads(e.read() or b"{}")

    def rows(self):
        if not self.rq_log.exists():
            return []
        return [line for line in self.rq_log.read_text().splitlines() if line]

    # ---- open -> handled -------------------------------------------------
    def test_handle_files_row_and_approved_ledger(self):
        code, body = self.post("operator-item/handle", {"id": "deadbeef"})
        self.assertEqual((code, body.get("ok")), (201, True))
        approved = json.loads(self.approved.read_text())["approved"]
        self.assertIn("deadbeef", approved)
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        self.assertIn("'progress'", rows[0])
        self.assertIn("'operator-item:deadbeef:handled'", rows[0])
        self.assertIn("operator-handle | ", self.handoffs.read_text())
        self.assertIn("automation|deadbeef | item marked handled",
                      self.handoffs.read_text())

    def test_handle_repeat_is_idempotent(self):
        self.post("operator-item/handle", {"id": "deadbeef"})
        code, body = self.post("operator-item/handle", {"id": "deadbeef"})
        self.assertEqual((code, body.get("ok")), (201, True))
        self.assertEqual(len(self.rows()), 1)
        approved = json.loads(self.approved.read_text())["approved"]
        self.assertEqual(list(approved), ["deadbeef"])

    # ---- open -> dismissed -----------------------------------------------
    def test_dismiss_files_row_and_merges_ledger(self):
        self.dismissed.write_text(
            json.dumps({"dismissed": {"00112233": "2026-01-01T00:00:00Z"}}))
        code, body = self.post("operator-item/dismiss", {"id": "deadbeef"})
        self.assertEqual((code, body.get("ok")), (201, True))
        dismissed = json.loads(self.dismissed.read_text())["dismissed"]
        self.assertEqual(set(dismissed), {"00112233", "deadbeef"})
        self.assertEqual(dismissed["00112233"], "2026-01-01T00:00:00Z")
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        self.assertIn("'operator-item:deadbeef:dismissed'", rows[0])
        # idempotent: the second post keeps its handoffs line but files
        # no second row and never re-stamps the ledger entry
        code, _ = self.post("operator-item/dismiss", {"id": "deadbeef"})
        self.assertEqual(code, 201)
        self.assertEqual(len(self.rows()), 1)

    # ---- fail closed / guards --------------------------------------------
    def test_row_failure_leaves_ledger_untouched(self):
        os.environ["HNGH_STUB_RQ_RC"] = "1"
        code, body = self.post("operator-item/handle", {"id": "deadbeef"})
        self.assertEqual(code, 500)
        self.assertFalse(body.get("ok"))
        self.assertFalse(self.approved.exists())
        self.assertFalse(self.handoffs.exists())
        code, _ = self.post("operator-item/dismiss", {"id": "deadbeef"})
        self.assertEqual(code, 500)
        self.assertEqual(json.loads(self.dismissed.read_text()), {})

    def test_bad_id_rejected(self):
        for route in ("operator-item/handle", "operator-item/dismiss"):
            code, _ = self.post(route, {"id": "bad id!"})
            self.assertEqual(code, 400)
        self.assertEqual(self.rows(), [])

    def test_token_required(self):
        code, _ = self.post("operator-item/handle", {"id": "deadbeef"},
                            token=False)
        self.assertEqual(code, 403)
        self.assertFalse(self.approved.exists())
        self.assertEqual(self.rows(), [])


class UiWiring(unittest.TestCase):
    """app.js must actually drive the transitions it renders."""

    def test_handle_affordance_posts_both_endpoints(self):
        a = Path(ROOT, "dashboard", "app.js").read_text()
        self.assertIn("postJson('/operator-item/handle', { id: id })", a)
        self.assertIn("postJson('/operator-item/dismiss', { id: id })", a)
        self.assertIn('data-handle-yes="', a)
        self.assertIn("it.status = 'handled'", a)


if __name__ == "__main__":
    unittest.main(verbosity=2)
