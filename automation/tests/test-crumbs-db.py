#!/usr/bin/env python3
"""crumbs-db sync contract tests (db-migration slice B).

Hermetic: tmp STATE.md via --state, tmp db via --db, the CLI
subprocessed (no import coupling with lib/crumbs-db.py).
"""

import sqlite3
import subprocess
import tempfile
import unittest
from pathlib import Path

AUTO_ROOT = Path(__file__).resolve().parents[1]
CLI = AUTO_ROOT / "lib" / "crumbs-db.py"

TS = "2026-09-22T10:00:00Z"


def crumb(ts, job, event, detail):
    return "%s | %s | %s | %s\n" % (ts, job, event, detail)


def run_sync(state, db):
    return subprocess.run(
        ["python3", "-B", str(CLI), "sync", "--state", str(state), "--db", str(db)],
        capture_output=True, text=True)


def db_count(db):
    conn = sqlite3.connect(db)
    try:
        return conn.execute("SELECT COUNT(*) FROM crumbs").fetchone()[0]
    finally:
        conn.close()


def db_meta(db, key):
    conn = sqlite3.connect(db)
    try:
        row = conn.execute("SELECT value FROM crumbs_meta WHERE key=?", (key,)).fetchone()
        return int(row[0]) if row else 0
    finally:
        conn.close()


class CrumbsDbSync(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.state = Path(self._td.name) / "STATE.md"
        self.db = Path(self._td.name) / "crumbs.db"

    def tearDown(self):
        self._td.cleanup()

    def _sync_ok(self):
        r = run_sync(self.state, self.db)
        self.assertEqual(r.returncode, 0, r.stderr)
        return r

    def test_import_then_idempotent_second_sync(self):
        self.state.write_text(crumb(TS, "job-a", "start", "one")
                              + crumb(TS, "job-b", "done", "two")
                              + crumb(TS, "job-c", "alert", "three"))
        self._sync_ok()
        self.assertEqual(db_count(self.db), 3)
        self._sync_ok()
        self.assertEqual(db_count(self.db), 3)  # idempotent
        self.assertEqual(db_meta(self.db, "state_byte_offset"),
                         self.state.stat().st_size)  # watermark unchanged

    def test_append_imports_exactly_one_more(self):
        self.state.write_text(crumb(TS, "j", "e", "d"))
        self._sync_ok()
        with self.state.open("a") as fh:
            fh.write(crumb(TS, "j", "e2", "d2"))
        self._sync_ok()
        self.assertEqual(db_count(self.db), 2)

    def test_mid_file_spill_line_skipped_and_counted(self):
        self.state.write_text(crumb(TS, "j", "e", "ok")
                              + "raw spill line with no pipes\n"
                              + crumb(TS, "j", "e2", "ok2"))
        self._sync_ok()
        self.assertEqual(db_count(self.db), 2)
        self.assertGreaterEqual(db_meta(self.db, "skipped_total"), 1)

    def test_bad_timestamp_row_skipped(self):
        self.state.write_text(crumb("not-a-ts", "j", "e", "d")
                              + crumb(TS, "j", "e2", "d2"))
        self._sync_ok()
        self.assertEqual(db_count(self.db), 1)
        self.assertGreaterEqual(db_meta(self.db, "skipped_total"), 1)

    def test_trailing_partial_line_waits_for_completion(self):
        self.state.write_text(crumb(TS, "j", "e", "d")
                              + "2026-09-22T10:00:01Z | j | partial")
        self._sync_ok()
        self.assertEqual(db_count(self.db), 1)
        with self.state.open("a") as fh:
            fh.write(" | done\n")
        self._sync_ok()
        self.assertEqual(db_count(self.db), 2)

    def test_additive_only_column_anchor(self):
        self.state.write_text(crumb(TS, "j", "e", "d"))
        self._sync_ok()
        conn = sqlite3.connect(self.db)
        try:
            cols = [row[1] for row in conn.execute("PRAGMA table_info(crumbs)")]
        finally:
            conn.close()
        # additive-only anchor: the legacy 4 columns stay, the writer
        # stamp column is appended (never renamed/reordered)
        self.assertEqual(cols, ["ts", "job", "event", "detail", "writer"])


if __name__ == "__main__":
    unittest.main()