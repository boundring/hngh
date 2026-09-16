#!/usr/bin/env python3
"""report-queue alert-kind redaction contract (2026-09-16 boundary
control): the report ledger is git-tracked and pushed to the public
origin, so `--add alert` must rewrite /home/<user>/... to ~/... and
/tmp/... to ~tmp/... before the text reaches a row or a body file.
Progress rows intentionally carry repo-relative paths in some lanes and
are NOT redacted (per-kind boundary, not a sink move). Redaction feeds
the row id, so two alerts differing only by machine-local path prefix
collapse to one id. Hermetic: HNGH_REPORT_ROOT points at a sandbox."""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RQ = ROOT.parent / "scripts" / "report-queue"


class AlertRedaction(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name)
        self.env = dict(os.environ, HNGH_REPORT_ROOT=str(self.root))

    def tearDown(self):
        self._td.cleanup()

    def add(self, kind, text, *extra):
        return subprocess.run(
            [sys.executable, str(RQ), "--add", kind, text, *extra],
            env=self.env, capture_output=True, text=True)

    def rows(self, kind="alert"):
        r = subprocess.run(
            [sys.executable, str(RQ), "--list", kind],
            env=self.env, capture_output=True, text=True)
        return [ln for ln in r.stdout.splitlines() if ln.startswith("|")]

    def body_text(self):
        bodies = list((self.root / "docs" / "project" / "report-bodies")
                      .glob("*.md"))
        self.assertEqual(len(bodies), 1)
        return bodies[0].read_text()

    def test_home_path_redacted_in_alert_row_and_body(self):
        r = self.add("alert", "lane x: missing source: "
                     "/home/aubergine/dots/vimrc")
        self.assertEqual(r.returncode, 0, r.stderr)
        first = self.rows()[0]
        self.assertIn("~/dots/vimrc", first)
        self.assertNotIn("/home/aubergine", first)
        self.assertIn("~/dots/vimrc", self.body_text())
        self.assertNotIn("/home/aubergine", self.body_text())

    def test_tmp_path_redacted_in_alert_row(self):
        r = self.add("alert", "stale-store: /tmp/hngh-cer-a.store "
                     "record.lisp untouched 30min+")
        self.assertEqual(r.returncode, 0, r.stderr)
        first = self.rows()[0]
        self.assertIn("~tmp/hngh-cer-a.store", first)
        self.assertNotIn("/tmp/hngh-cer-a.store", first)

    def test_bare_tmp_token_redacted(self):
        r = self.add("alert", "tmp root /tmp is full")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("~tmp is full", self.rows()[0])

    def test_tmpfile_style_word_untouched(self):
        r = self.add("alert", "odd path /tmpfile name kept")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("/tmpfile", self.rows()[0])

    def test_progress_kind_not_redacted(self):
        r = self.add("progress", "lane note: scratch at /tmp/keep-me")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("/tmp/keep-me", self.rows("progress")[0])

    def test_url_home_component_not_redacted(self):
        r = self.add("alert", "see https://x.io/home/aubergine/f for docs")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("https://x.io/home/aubergine/f", self.rows()[0])

    def test_row_id_computed_from_redacted_text(self):
        self.assertEqual(self.add("alert", "missing /home/aubergine/a.conf")
                         .returncode, 0)
        self.assertEqual(self.add("alert", "missing /home/otheruser/a.conf")
                         .returncode, 0)
        ids = {ln.split(" | ")[2] for ln in self.rows()}
        self.assertEqual(len(ids), 1, f"ids diverged: {sorted(ids)}")

    def test_identity_dedup_still_works_after_redaction(self):
        self.assertEqual(self.add(
            "alert", "stale /tmp/store-a untouched",
            "--identity", "k:/tmp/store-a", "--evidence", "e1").returncode, 0)
        self.assertEqual(len(self.rows()), 1)
        r = self.add("alert", "stale /tmp/store-a untouched",
                     "--identity", "k:/tmp/store-a", "--evidence", "e1")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(len(self.rows()), 1)
        self.assertIn("suppressed duplicate", r.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
