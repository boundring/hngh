#!/usr/bin/env python3
"""Dashboard feedback capture layer, hermetic.

Operator interactivity directive (2026-09-11): pips on the dashboard
open an enlargeable text field; POST /api/feedback files one timestamped
JSON per submission; jobs/feedback-ingest.py standardizes each file
into the existing operator-item contract (alert row + breadcrumb) so it
lands on the dashboard operator-items feed.

Everything runs against seamed paths: the server test binds a
ThreadingHTTPServer on port 0 with dashboard-server.FEEDBACK pointed
into a tmp dir; the ingest test seams AUTOMATION_ROOT/STATE_FILE/
HNGH_REPORT_ROOT and the email channel (dormant by design) exactly like
test-cap-block-operator-item.py. No real ledger, no real dashboard
files, no network beyond localhost.
"""
import importlib.util
import http.client
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import unittest
import urllib.parse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # automation/
KERNEL = ROOT.parent  # repo root


def _load(name, rel):
    spec = importlib.util.spec_from_file_location(
        name, str(ROOT / rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


ds = _load("dashboard_server", "dashboard-server.py")
fi = _load("feedback_ingest", "jobs/feedback-ingest.py")


class EndpointTest(unittest.TestCase):
    """POST /api/feedback over a real bound server, seamed FEEDBACK dir."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.fb_dir = self.tmp / "feedback"
        ds.FEEDBACK = str(self.fb_dir)
        ds.Handler._fb_last = {}
        ds.Handler.protocol_version = "HTTP/1.1"
        self.httpd = ds.ThreadingHTTPServer(("127.0.0.1", 0), ds.Handler)
        self.t = threading.Thread(target=self.httpd.serve_forever, daemon=True)
        self.t.start()
        self.port = self.httpd.server_address[1]

    def tearDown(self):
        self.httpd.shutdown()
        self.httpd.server_close()
        shutil.rmtree(self.tmp, ignore_errors=True)

    def post(self, payload):
        c = http.client.HTTPConnection("127.0.0.1", self.port, timeout=10)
        body = json.dumps(payload)
        c.request("POST", "/api/feedback", body,
                  {"Content-Type": "application/json",
                   "Connection": "close"})
        r = c.getresponse()
        data = r.read()
        c.close()
        return r.status, json.loads(data) if data else {}

    def files(self):
        return sorted(p for p in self.fb_dir.glob("*.json")) if self.fb_dir.exists() else []

    def post_form(self, fields):
        """urlencoded form POST — the encoding HTML email forms use."""
        c = http.client.HTTPConnection("127.0.0.1", self.port, timeout=10)
        c.request("POST", "/api/feedback", urllib.parse.urlencode(fields),
                  {"Content-Type": "application/x-www-form-urlencoded",
                   "Connection": "close"})
        r = c.getresponse()
        data = r.read()
        c.close()
        return r.status, json.loads(data) if data else {}

    def test_form_encoded_accepted_same_shape(self):
        st, _ = self.post_form({"type": "idea", "text": "send form entries",
                                "element": "digest email"})
        self.assertEqual(st, 201)
        files = self.files()
        self.assertEqual(len(files), 1)
        rec = json.loads(files[0].read_text())
        self.assertEqual(rec["type"], "idea")
        self.assertEqual(rec["text"], "send form entries")
        self.assertEqual(rec["element"], "digest email")
        self.assertRegex(rec["ts"], r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")

    def test_form_encoded_malformed_rejected(self):
        st, _ = self.post_form({"type": "nope", "text": "x"})
        self.assertEqual(st, 400)
        st, _ = self.post_form({"type": "idea", "text": ""})
        self.assertEqual(st, 400)
        self.assertEqual(len(self.files()), 0)

    def test_writes_one_file(self):
        st, body = self.post({"type": "css-theme", "text": "font+ on headers",
                              "element": "tab bar"})
        self.assertEqual(st, 201)
        files = self.files()
        self.assertEqual(len(files), 1)
        rec = json.loads(files[0].read_text())
        self.assertEqual(rec["type"], "css-theme")
        self.assertEqual(rec["text"], "font+ on headers")
        self.assertEqual(rec["element"], "tab bar")
        self.assertRegex(rec["ts"], r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")

    def test_oversize_rejected(self):
        st, body = self.post({"type": "idea", "text": "x" * 2001})
        self.assertEqual(st, 400)
        self.assertEqual(len(self.files()), 0)

    def test_bad_type_rejected(self):
        st, _ = self.post({"type": "nuclear-launch", "text": "hi"})
        self.assertEqual(st, 400)

    def test_rate_guard(self):
        st1, _ = self.post({"type": "correction", "text": "one"})
        st2, _ = self.post({"type": "correction", "text": "two"})
        st3, _ = self.post({"type": "correction", "text": "three"})
        self.assertEqual(st1, 201)
        self.assertEqual(st2, 429)
        self.assertEqual(st3, 429)
        self.assertEqual(len(self.files()), 1)


class IngestTest(unittest.TestCase):
    """feedback-ingest files one standardized operator-item row, hermetic."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.fb = self.tmp / "dashboard" / "feedback"
        self.fb.mkdir(parents=True)
        fi.FEEDBACK = str(self.fb)
        fi.PROCESSED = str(self.fb / "processed")
        fi.AUTOMATION_ROOT = str(self.tmp)
        fi.REPORT_ROOT = str(self.tmp)
        (self.tmp / "docs" / "project").mkdir(parents=True)  # report-queue seam

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def write_rec(self, rec, name="fb.json"):
        (self.fb / name).write_text(json.dumps(rec))

    def run_ingest(self):
        return fi.main([])

    def report_rows(self):
        md = (self.tmp / "docs" / "project" / "reports.md")
        if not md.exists():
            return []
        return [l for l in md.read_text().splitlines()
                if l.strip().startswith("|")
                and not l.strip().startswith("| timestamp")]

    def test_files_standardized_row_and_marks_processed(self):
        self.write_rec({"ts": "2026-09-11T03:00:00Z", "type": "css-theme",
                        "text": "font+ on headers", "element": "tab bar"})
        self.assertEqual(self.run_ingest(), 0)
        rows = self.report_rows()
        self.assertEqual(len(rows), 1)
        self.assertIn("[feedback:css-theme][quick] tab bar: increase base "
                      "font size on headers", rows[0])
        # moved to processed/ -> the dedupe marker
        self.assertFalse((self.fb / "fb.json").exists())
        self.assertTrue((self.fb / "processed" / "fb.json").exists())
        # landed on the feed the dashboard consumes (STATE.md alert crumb)
        state = (self.tmp / "STATE.md").read_text()
        self.assertRegex(state, r"\| alert \| ")

    def test_double_ingest_noops(self):
        self.write_rec({"ts": "2026-09-11T03:00:00Z", "type": "idea",
                        "text": "add a gantt chip", "element": "camp"})
        self.assertEqual(self.run_ingest(), 0)
        self.assertEqual(self.run_ingest(), 0)
        self.assertEqual(len(self.report_rows()), 1)

    def test_non_quick_type_has_no_quick_marker(self):
        self.write_rec({"ts": "2026-09-11T03:00:00Z", "type": "correction",
                        "text": "counter is negative", "element": "system"})
        self.assertEqual(self.run_ingest(), 0)
        self.assertIn("[feedback:correction] system: counter is negative",
                      self.report_rows()[0])

    def test_shorthand_expansion(self):
        self.assertEqual(
            fi.expand("  font-  margin+ gap-  "),
            "decrease base font size increase margins decrease panel gap")
        self.assertEqual(fi.expand("plain   text"), "plain text")


if __name__ == "__main__":
    unittest.main(verbosity=2)