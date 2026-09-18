#!/usr/bin/env python3
"""email-digest alert intake tolerates overwide ledger rows (2026-09-18,
plan 2026-09-18-backlog-p0-security-fixes step 1, backlog item
rq-gap-email-digest-intake): a patrol alert whose detail contains a
literal `|` (e.g. `send failed rc=2: ...` log lines) lands in
docs/project/reports.md as a 6-cell row, which report-queue's strict
5-cell read silently drops — and the digest then never surfaces the
alert. The digest's alert_rows recovers those rows by parsing the
reports table directly. Hermetic: fixture reports.md via HNGH_HOME."""

import importlib.util
import os
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIGEST = ROOT / "scripts" / "email-digest.py"

_spec = importlib.util.spec_from_file_location("email_digest_intake", DIGEST)
ed = importlib.util.module_from_spec(_spec)
sys.modules["email_digest_intake"] = ed
_spec.loader.exec_module(ed)

NOW = "2026-09-18T03:00:00Z"
FRESH_ROW = (
    "| 2026-09-18T02:50:45Z | alert | eeb029c7 "
    "| patrol email: send-failed on notify-email.log "
    "-- 1 failed send(s) since last patrol, last: "
    "2026-09-18T02:47:43Z "
    "| send failed rc=2: notify-email: 1password unavailable "
    "— conf pass fallback "
    "| 2026-09-18T02:50:45Z-alert-eeb029c7.md |")
STALE_ROW = FRESH_ROW.replace("2026-09-18T02:50:45Z",
                              "2026-08-20T02:50:45Z")
NORMAL_ROW = ("| 2026-09-18T01:00:00Z | alert | ab12cd34 "
              "| plain alert line no pipes "
              "| 2026-09-18T01:00:00Z-alert-ab12cd34.md |")


class OverwideAlertIntake(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="hnghdigestintake-")
        os.makedirs(os.path.join(self.root, "docs", "project"))
        self.reports = os.path.join(self.root, "docs", "project", "reports.md")
        os.environ["HNGH_HOME"] = self.root

    def tearDown(self):
        os.environ.pop("HNGH_HOME", None)

    def write(self, text):
        with open(self.reports, "w", encoding="utf-8") as fh:
            fh.write("| timestamp | kind | id | first line | body |\n"
                     + text + "\n")

    def test_overwide_alert_row_is_recovered(self):
        self.write(NORMAL_ROW + "\n" + FRESH_ROW)
        rows = ed._overwide_alert_rows()
        self.assertEqual(len(rows), 1)  # 5-cell rows come via --json, not here
        over = rows[0]
        self.assertIn("send failed rc=2: notify-email: "
                      "1password unavailable", over)
        self.assertIn("-- 1 failed send(s) since last patrol", over)

    def test_stale_overwide_row_is_windowed_out(self):
        self.write(NORMAL_ROW + "\n" + STALE_ROW)
        rows = ed._overwide_alert_rows()
        self.assertEqual(rows, [])  # stale overwide row is out of window;
        # the in-window 5-cell row comes via the --json path instead

    def test_non_alert_and_bad_body_rows_are_not_recovered(self):
        bad = [
            # wrong kind cell
            FRESH_ROW.replace("| alert |", "| progress |"),
            # body cell missing the alert-body naming shape
            FRESH_ROW.replace("-alert-eeb029c7.md |", "-x.md |"),
            # timestamp cell not the ledger hour form
            FRESH_ROW.replace("| 2026-09-18T02:50:45Z | alert",
                              "| not-a-ts | alert"),
            # short row (dropped for a different reason: a lost cell)
            "| 2026-09-18T02:50:45Z | alert | short-id | oops |",
        ]
        for row in bad:
            self.write(row)
            self.assertEqual(ed._overwide_alert_rows(), [],
                             "must not recover malformed row: %s" % row)

    def test_missing_reports_file_is_empty(self):
        self.assertEqual(ed._overwide_alert_rows(), [])

    def test_alert_rows_env_seam_still_wins(self):
        os.environ["HNGH_DIGEST_ALERTS"] = "env-seam alert"
        try:
            self.assertEqual(ed.alert_rows(), ["env-seam alert"])
        finally:
            os.environ.pop("HNGH_DIGEST_ALERTS", None)


if __name__ == "__main__":
    unittest.main()
