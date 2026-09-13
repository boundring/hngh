#!/usr/bin/env python3
"""digest-local hermetic proof (2026-09-13 operator directive): one daily
digest renders into the hngh home dispatch dir ($HNGH_HOME_DIR/dispatch/
<date>/index.html, create-if-missing); a missing digest fails closed."""
import os
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # automation/
DIGEST_LOCAL = ROOT / "jobs" / "digest-local.py"

FIX_DIGEST = """# 2026-09-13

## 0800
DECK A: TEST SIGNAL -- fixture block (https://example.com/x)
"""


class TestDigestLocal(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.mkdtemp(prefix="hnghdispatch-")
        self.addCleanup(self._rm, tmp)
        self.home = os.path.join(tmp, "home")
        self.digests = os.path.join(tmp, "digest")
        os.makedirs(self.digests)
        with open(os.path.join(self.digests, "2026-09-13.md"), "w",
                  encoding="utf-8") as fh:
            fh.write(FIX_DIGEST)
        db = os.path.join(tmp, "telemetry.db")
        con = sqlite3.connect(db)
        con.execute(
            "CREATE TABLE events(ts TEXT, source TEXT, kind TEXT,"
            " identity TEXT, lane TEXT, unit TEXT, model TEXT,"
            " tokens_in INTEGER, tokens_out INTEGER, cost_usd REAL,"
            " wall_s REAL, subject TEXT, refs TEXT, body TEXT)")
        con.execute(
            "INSERT INTO events(ts, kind, cost_usd)"
            " VALUES (datetime('now','-1 hour'),'session-cost',1.25)")
        con.commit()
        con.close()
        self.env = dict(os.environ, HNGH_HOME_DIR=self.home,
                        HNGH_DIGESTS_DIR=self.digests,
                        HNGH_TELEMETRY_DB=db)

    @staticmethod
    def _rm(path):
        import shutil
        shutil.rmtree(path, ignore_errors=True)

    def _run(self, date):
        return subprocess.run(
            [sys.executable, "-B", str(DIGEST_LOCAL), date],
            env=self.env, capture_output=True, text=True)

    def test_renders_index_into_home_dispatch(self):
        r = self._run("2026-09-13")
        self.assertEqual(r.returncode, 0, r.stderr)
        idx = os.path.join(self.home, "dispatch", "2026-09-13",
                           "index.html")
        # create-if-missing: home/dispatch/<date> did not pre-exist
        self.assertTrue(os.path.isfile(idx), r.stderr)
        with open(idx, encoding="utf-8") as fh:
            html = fh.read()
        self.assertIn("<html", html.lower())
        self.assertIn("2026-09-13", html)

    def test_missing_digest_fails_closed(self):
        r = self._run("1999-01-01")
        self.assertNotEqual(r.returncode, 0)
        self.assertFalse(os.path.exists(
            os.path.join(self.home, "dispatch", "1999-01-01")))


if __name__ == "__main__":
    unittest.main()
