#!/usr/bin/env python3
"""Regression test: overnight-cycle alert-source awk handles leading-space
timestamp cells (2026-09-18, plan 2026-09-18-backlog-p0-security-fixes
step 2, backlog item rq-gap-overnight-awk-disposition). The old pattern
`$3 ~ /alert/ && $2 >= c` is a dead filter: reports.md table rows are
rendered as `| 2026-...Z | alert | ...`, so with -F'|' the ts cell is
" 2026-...Z " and every lexicographic compare against a bare cutoff is
false — no alert row ever reached the draft-plan source material. The
fixed pattern strips leading whitespace before the compare. Hermetic:
extracts the production awk program from scripts/overnight-cycle.sh by
line span and runs it against fixture rows."""

import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "scripts" / "overnight-cycle.sh"

ALERT_LEADED = ("|  2026-09-18T05:00:00Z | alert | abc12345 "
                "| patrol: check-x pending over an hour "
                "| 2026-09-18T05:00:00Z-alert-abc12345.md |")
ALERT_FLAT = ("| 2026-09-18T05:30:00Z | alert | def67890 "
              "| another alert row, flat ts cell "
              "| 2026-09-18T05:30:00Z-alert-def67890.md |")
ALERT_STALE_LEADED = ("|  2026-09-16T05:00:00Z | alert | old12345 "
                      "| stale alert, leading-space ts "
                      "| 2026-09-16T05:00:00Z-alert-old12345.md |")
PROGRESS_ROW = ("| 2026-09-18T06:00:00Z | progress | aaa11111 "
                "| progress row, must not match kind=/alert/ "
                "| 2026-09-18T06:00:00Z-progress-aaa11111.md |")


def extract_awk():
    text = SCRIPT.read_text(errors="replace")
    # author_draft_plan's alert-source awk: find author_draft_plan
    start = text.index("author_draft_plan")
    seg = text[start:]
    m = re.search(r"alerts=\"\$\(awk -F'\|' -v c=\"\$cutoff\" '\n(.*?)'",
                  seg, re.S)
    if not m:
        raise AssertionError("alert-source awk program not found")
    return m.group(1)


class OvernightAwkDisposition(unittest.TestCase):
    def setUp(self):
        self.body = extract_awk()

    def run_awk(self, cutoff, *rows):
        fixture = "\n".join(rows) + "\n"
        p = subprocess.run(
            ["awk", "-F|", "-v", "c=" + cutoff, self.body],
            input=fixture, capture_output=True, text=True, check=True)
        return [l for l in p.stdout.splitlines() if l.strip()]

    def test_leading_space_ts_matches(self):
        out = self.run_awk("2026-09-17T00:00", ALERT_LEADED)
        self.assertEqual(len(out), 1)
        self.assertIn("abc12345", out[0])

    def test_flat_ts_still_matches(self):
        out = self.run_awk("2026-09-17T00:00", ALERT_FLAT)
        self.assertEqual(len(out), 1)
        self.assertIn("def67890", out[0])

    def test_stale_leaded_row_windowed_out(self):
        out = self.run_awk("2026-09-17T00:00", ALERT_STALE_LEADED)
        self.assertEqual(out, [])

    def test_progress_kind_not_matched(self):
        out = self.run_awk("2026-09-17T00:00", PROGRESS_ROW)
        self.assertEqual(out, [])

    def test_mixed_rows_dedup_by_id_newest_wins(self):
        out = self.run_awk("2026-09-17T00:00",
                           ALERT_LEADED, ALERT_FLAT, PROGRESS_ROW,
                           ALERT_STALE_LEADED)
        self.assertEqual(len(out), 2)
        joined = "\n".join(out)
        self.assertIn("abc12345", joined)
        self.assertIn("def67890", joined)
        self.assertNotIn("old12345", joined)


if __name__ == "__main__":
    unittest.main()
