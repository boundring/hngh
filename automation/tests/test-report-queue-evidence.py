#!/usr/bin/env python3
"""report-queue evidence-gated dedup (2026-09-13): a same-identity
re-alert only re-fires when the underlying condition recurred (fresh
evidence token); an unchanged stale condition is suppressed with a body
breadcrumb — no duplicate row, no ×N bump."""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RQ = ROOT.parent / "scripts" / "report-queue"

TEXT = ("patrol email: send-failed on notify-email.log -- "
        "9 failed send(s) today, last: 2026-09-13T16:24:25Z")
STALE = "9 failed send(s) today, last: 2026-09-13T16:24:25Z"
FRESH = "10 failed send(s) today, last: 2026-09-13T18:40:11Z"


class EvidenceDedup(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name)
        self.env = dict(os.environ, HNGH_REPORT_ROOT=str(self.root))

    def tearDown(self):
        self._td.cleanup()

    def add(self, *extra):
        return subprocess.run(
            [sys.executable, str(RQ), "--add", "alert", TEXT,
             "--identity", "patrol:email", *extra],
            env=self.env, capture_output=True, text=True)

    def rows(self):
        r = subprocess.run([sys.executable, str(RQ), "--list", "alert"],
                           env=self.env, capture_output=True, text=True)
        return [ln for ln in r.stdout.splitlines() if ln.startswith("|")]

    def body(self):
        bodies = list((self.root / "docs" / "project" / "report-bodies")
                      .glob("*-alert-*.md"))
        self.assertEqual(len(bodies), 1)
        return bodies[0].read_text()

    def test_same_evidence_suppressed_no_duplicate_row(self):
        self.assertEqual(self.add("--evidence", STALE).returncode, 0)
        self.assertEqual(len(self.rows()), 1)
        r = self.add("--evidence", STALE)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(len(self.rows()), 1)
        self.assertIn("suppressed duplicate", r.stdout)
        self.assertIn("suppressed duplicate (no new evidence)",
                      self.body())
        self.assertNotIn(" ×2", self.rows()[0])

    def test_new_evidence_refires_as_bump(self):
        self.add("--evidence", STALE)
        r = self.add("--evidence", FRESH)
        self.assertEqual(r.returncode, 0, r.stderr)
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        self.assertIn(" ×2", rows[0])
        self.assertIn("- **last-evidence:** " + FRESH, self.body())
        self.assertIn("occurrence", self.body())

    def test_without_evidence_legacy_bump_unchanged(self):
        self.add()
        r = self.add()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(len(self.rows()), 1)
        self.assertIn(" ×2", self.rows()[0])


if __name__ == "__main__":
    unittest.main(verbosity=2)
