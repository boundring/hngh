#!/usr/bin/env python3
"""Report queue smoke: the append-only ledger's CLI contract, hermetic.

Everything runs through the real script in a disposable temp root
(HNGH_REPORT_ROOT), so no repo file is touched and no network is used.
Contract: --add writes a row + body and refuses a bad kind / empty text
(exit 2); --list and --list KIND are newest-first; --json carries rows,
an unread count, and a per-kind summary; --unread without a cursor
returns every row and advances only via --mark-read.
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = ROOT / "scripts" / "report-queue"


def run(root, *args):
    env = dict(os.environ)
    env["HNGH_REPORT_ROOT"] = str(root)
    return subprocess.run([sys.executable, str(SCRIPT), *args],
                          capture_output=True, text=True, env=env)


class ReportQueueCLI(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name)

    def tearDown(self):
        self._td.cleanup()

    def reports_path(self):
        return self.root / "docs" / "project" / "reports.md"

    def bodies(self):
        d = self.root / "docs" / "project" / "report-bodies"
        return sorted(p.name for p in d.glob("*.md")) if d.exists() else []

    def add(self, kind, text):
        return run(self.root, "--add", kind, text)

    def test_help_exits_zero(self):
        out = run(self.root, "--help")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("report-queue", out.stdout)

    def test_add_writes_row_and_body(self):
        out = self.add("progress", "Wired the report queue end to end.")
        self.assertEqual(out.returncode, 0, out.stderr)
        text = self.reports_path().read_text()
        self.assertTrue(text.startswith("| timestamp | kind | id | first line | body |"))
        row = next(l for l in text.splitlines() if "Wired the" in l)
        cells = [c.strip() for c in row.strip("|").split("|")]
        self.assertEqual(cells[1], "progress")
        self.assertEqual(cells[3], "Wired the report queue end to end.")
        self.assertEqual(len(self.bodies()), 1, "one body file written")
        self.assertIn("Wired the report queue", self.bodies_md())

    def bodies_md(self):
        d = self.root / "docs" / "project" / "report-bodies"
        return (d / self.bodies()[0]).read_text()

    def test_list_is_newest_first_and_filters_by_kind(self):
        self.add("progress", "alpha progress")
        self.add("alert", "alpha alert")
        self.add("progress", "beta progress")
        out = run(self.root, "--list")
        self.assertEqual(out.returncode, 0, out.stderr)
        lines = [l for l in out.stdout.splitlines() if l.startswith("|")]
        self.assertEqual(len(lines), 3)
        # newest first: the last-added progress row is top
        self.assertIn("beta progress", lines[0])
        self.assertIn("alpha progress", lines[2])
        filt = run(self.root, "--list", "alert")
        flines = [l for l in filt.stdout.splitlines() if l.startswith("|")]
        self.assertEqual(len(flines), 1)
        self.assertIn("alpha alert", flines[0])

    def test_unread_missing_cursor_returns_rows_then_mark_read_advances(self):
        self.add("progress", "first")
        self.add("alert", "second")
        before = [l for l in run(self.root, "--unread").stdout.splitlines()
                  if l.startswith("|")]
        self.assertEqual(len(before), 2)
        # mark the first row read: unread should drop to the newer rows
        first_id = before[1].split(" | ")[2]  # newest-first, so last row is oldest
        out = run(self.root, "--mark-read", first_id)
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertEqual(self.cursor().strip(), first_id)
        after = [l for l in run(self.root, "--unread").stdout.splitlines()
                 if l.startswith("|")]
        self.assertEqual(len(after), 1)

    def test_mark_read_unknown_refuses(self):
        out = run(self.root, "--mark-read", "deadbeef")
        self.assertEqual(out.returncode, 2)
        self.assertIn("unknown", out.stderr)

    def test_bad_kind_refuses(self):
        out = self.add("bogus", "x")
        self.assertEqual(out.returncode, 2)
        self.assertIn("bad kind", out.stderr)
        self.assertFalse(self.reports_path().exists())

    def test_empty_text_refuses(self):
        out = self.add("progress", "   ")
        self.assertEqual(out.returncode, 2)
        self.assertIn("empty TEXT", out.stderr)
        self.assertFalse(self.reports_path().exists())

    def test_json_carries_rows_summary_and_unread(self):
        self.add("progress", "json progress")
        self.add("alert", "json alert")
        out = run(self.root, "--json")
        self.assertEqual(out.returncode, 0, out.stderr)
        doc = json.loads(out.stdout)
        self.assertEqual(len(doc["reports"]), 2)
        self.assertEqual(doc["unread"], 2)
        self.assertEqual(doc["summary"]["progress"], 1)
        self.assertEqual(doc["summary"]["alert"], 1)
        self.assertIn("json alert", doc["reports"][0]["body"])
        self.assertIn("json progress", doc["reports"][1]["body"])
        # newest first in the dashboard payload too
        self.assertEqual(doc["reports"][0]["kind"], "alert")

    def cursor(self):
        p = self.root / "docs" / "project" / "report-cursor"
        return p.read_text() if p.exists() else ""


if __name__ == "__main__":
    unittest.main(verbosity=2)