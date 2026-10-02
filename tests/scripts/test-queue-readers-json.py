#!/usr/bin/env python3
"""Queue readers (dashboard-tui + osd-operative) vs the report-queue
--json contract.

Regression (2026-10-02): both readers passed `--json --unread`, but
report-queue dispatches --unread before --json, so the readers always
got unread-count TEXT and json.loads failed — the TUI queue tab showed
"queue not alive" and the osd strip omitted the reports bit forever.
They also read the wrong schema key (first_line; the payload key is
`first`) and treated the `body` value as a filename (it is body text).
Hermetic: the real report-queue seeds a sandbox queue via
HNGH_REPORT_ROOT; the readers' module constants are pointed there."""
import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
TUI = ROOT / "scripts" / "dashboard-tui"
OSD = ROOT / "scripts" / "osd-operative"


def load(path, name):
    loader = importlib.machinery.SourceFileLoader(name, str(path))
    spec = importlib.util.spec_from_loader(name, loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


class TestQueueReaders(unittest.TestCase):
    def setUp(self):
        self.sb = tempfile.TemporaryDirectory()
        self.addCleanup(self.sb.cleanup)
        self.root = Path(self.sb.name)
        # the readers shell out to the real report-queue with the
        # inherited environment — the root seam must hold for them too
        os.environ["HNGH_REPORT_ROOT"] = str(self.root)
        self.addCleanup(os.environ.pop, "HNGH_REPORT_ROOT", None)
        env = dict(os.environ, HNGH_REPORT_ROOT=str(self.root))
        for kind, text in (("alert", "kernel red gate: make test failed"),
                           ("progress", "config-backup lane: ok 3 files")):
            p = subprocess.run(
                [sys.executable, str(ROOT / "scripts" / "report-queue"),
                 "--add", kind, text],
                capture_output=True, text=True, env=env, cwd=str(ROOT))
            self.assertEqual(p.returncode, 0, p.stderr)
        # the readers keep their real-script paths; the env seam alone
        # routes their data access into the sandbox
        self.tui = load(TUI, "dashboard_tui_queue_readers_test")
        self.osd = load(OSD, "osd_operative_queue_readers_test")

    def payload(self):
        p = subprocess.run(
            [sys.executable, str(ROOT / "scripts" / "report-queue"),
             "--json"], capture_output=True, text=True,
            env=dict(os.environ, HNGH_REPORT_ROOT=str(self.root)),
            cwd=str(ROOT))
        self.assertEqual(p.returncode, 0, p.stderr)
        return json.loads(p.stdout)

    def test_tui_reports_parses_json_payload(self):
        reports, unread, ok = self.tui._reports()
        self.assertTrue(ok)
        self.assertEqual(unread, 2)
        self.assertEqual(len(reports), 2)
        self.assertEqual({r["kind"] for r in reports},
                         {"alert", "progress"})

    def test_tui_body_text_uses_payload_body(self):
        alert = next(r for r in self.tui._reports()[0]
                     if r["kind"] == "alert")
        text = self.tui._report_body_text(alert)
        self.assertIn("make test failed", text)

    def test_osd_report_status_renders_first_report(self):
        status = self.osd.report_status()
        self.assertTrue(status, "report_status returned empty")
        # rows seeded in the same minute tie on the minute-resolution
        # ts; pin "renders the newest row's kind + first line", not the
        # tie order
        self.assertTrue(status.lstrip().startswith("·"), status)
        self.assertTrue(any(f in status for f in
                            ("make test failed", "ok 3 files")), status)


if __name__ == "__main__":
    unittest.main()
