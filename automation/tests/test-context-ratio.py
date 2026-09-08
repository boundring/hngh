#!/usr/bin/env python3
"""context-ratio vital sign, hermetic (no real telemetry, no reports).

The producer (jobs/context-ratio.py) reads the last 7 days of
kind=session-cost telemetry rows, computes per-session in:out ratios,
and files ONE identity-deduped report-queue progress row (identity
context-ratio:<date>): sessions counted, median ratio paid vs local,
worst session, trend vs the previous row (or "first run"). Model-free.
"""

import os
import sqlite3
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PRODUCER = ROOT / "jobs" / "context-ratio.py"

KERNEL = os.environ.get("HNGH_HOME") or str(
    Path.home() / "Projects" / "etc" / "hngh")


class ContextRatio(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name)
        self.db = self.root / "dashboard" / "telemetry.db"
        self.db.parent.mkdir(parents=True)
        conn = sqlite3.connect(self.db)
        conn.execute("CREATE TABLE events(ts TEXT, kind TEXT, model TEXT,"
                     " tokens_in INTEGER, tokens_out INTEGER)")
        conn.commit()
        conn.close()
        self.now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        self.day = time.strftime("%Y-%m-%d", time.gmtime())

    def tearDown(self):
        self._td.cleanup()

    def seed(self, rows):
        conn = sqlite3.connect(self.db)
        conn.executemany(
            "insert into events(ts, kind, model, tokens_in, tokens_out)"
            " values (?, 'session-cost', ?, ?, ?)", rows)
        conn.commit()
        conn.close()

    def run_producer(self):
        import importlib.util
        os.environ.update(
            HNGH_TELEMETRY_DB=str(self.db),
            HNGH_REPORT_ROOT=str(self.root),
            HNGH_HOME=KERNEL)
        spec = importlib.util.spec_from_file_location(
            "context_ratio", str(PRODUCER))
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        return mod

    def rows(self):
        rep = self.root / "docs" / "project" / "reports.md"
        if not rep.exists():
            return []
        return [ln for ln in rep.read_text().splitlines()
                if ln.startswith("| ") and "kind" not in ln]

    def test_medians_worst_and_first_run(self):
        # paid: 10, 20, 30 -> median 20; local: 100, 200 -> median 150;
        # worst 200 (local); out<=0 and null-token rows excluded
        self.seed([
            (self.now, "zai/glm-5.3", 100, 10),
            (self.now, "zai/glm-5.3", 200, 10),
            (self.now, "zai/glm-5.3", 300, 10),
            (self.now, "unsloth/Ornith-1.0-35B", 1000, 10),
            (self.now, "unsloth/Ornith-1.0-35B", 2000, 10),
            (self.now, "unsloth/Ornith-1.0-35B", 5000, 0),    # excluded
            (self.now, "unsloth/Ornith-1.0-35B", None, None),  # excluded
        ])
        mod = self.run_producer()
        mod.main()
        rows = self.rows()
        self.assertEqual(len(rows), 1, rows)
        first = rows[0]
        self.assertIn("| progress |", first)
        self.assertIn(
            "context-ratio %s: sessions=5 paid_median=20.0 "
            "local_median=150.0 worst=200.0 (unsloth/Ornith-1.0-35B) "
            "trend: first run" % self.day, first)

    def test_identity_dedup_one_row_per_day(self):
        self.seed([(self.now, "zai/glm-5.3", 100, 10)])
        mod = self.run_producer()
        mod.main()
        mod.main()  # re-run same day: bump, never a second row
        rows = [ln for ln in self.rows() if "context-ratio" in ln]
        self.assertEqual(len(rows), 1, rows)

    def test_trend_vs_previous_row(self):
        # yesterday's row: paid 40.0, local 300.0 -> today must read down
        prev_day = "2000-01-01"
        mod = self.run_producer()
        rq = mod.load_report_queue()
        rq.add("progress",
               "context-ratio %s: sessions=9 paid_median=40.0 "
               "local_median=300.0 worst=300.0 (x) trend: first run" % prev_day,
               "context-ratio:" + prev_day, 0)  # window 0: unlimited
        self.seed([(self.now, "zai/glm-5.3", 100, 10)])  # paid ratio 10
        mod = self.run_producer()
        mod.main()
        row = [ln for ln in self.rows() if prev_day not in ln][0]
        self.assertIn("paid_median=10.0", row)
        self.assertIn("40.0->10.0 (down)", row)

    def test_empty_telemetry_files_nothing(self):
        mod = self.run_producer()
        mod.main()  # no rows: no report, no crash
        self.assertEqual(self.rows(), [])


if __name__ == "__main__":
    unittest.main()
