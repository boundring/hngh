#!/usr/bin/env python3
"""Cap-block operator-item filing path, hermetic.

The 2026-09-09 budget-governance directive
(docs/records/2026-09-09-budget-governance-directive.md): when the
sessions-day-max cap blocks an operator-priority plan, overnight-cycle
files an operator-item requesting the cap amendment instead of silently
waiting or burning filler. This test exercises the filing helper
(lib/operator-item.sh -> lib/notify-email.sh alert_row -> kernel
scripts/report-queue) against env-seamed roots only (HNGH_REPORT_ROOT /
STATE_FILE / AUTOMATION_ROOT pointed into a tmp dir) -- never the real
ledger, never a real cap change, never the email channel (the conf seam
points at a nonexistent path, so the channel is dormant by design).

The consumer surface (automation/cadence/1m/05-operator-items.sh ->
jobs/operator-items-feed.py) reads STATE.md crumbs whose event matches
^alert or whose joined text matches papercut|flagged|needs|"operator
decision"; those two criteria are replicated here to assert the filed
item would land on the dashboard feed.
"""

import hashlib
import json
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # automation/
KERNEL = ROOT.parent  # repo root (scripts/report-queue lives here)

# jobs/operator-items-feed.py's own operator-item criterion
KEYWORD_RE = re.compile(r"papercut|flagged|needs|operator decision", re.I)

IDENTITY = "cap-block-2026-09-09"
TEXT = ("operator decision requested: sessions-day-max cap blocks "
        "operator-priority plans today (overnight sessions today >= cap; "
        "see docs/records/2026-09-09-budget-governance-directive.md). "
        "Amend the cap or reprioritize; spend caps are never amended "
        "unilaterally by machine sessions.")


def sha8(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()[:8]


class CapBlockOperatorItem(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.env = {
            "PATH": os.environ["PATH"],
            "AUTOMATION_ROOT": str(self.tmp),
            "STATE_FILE": str(self.tmp / "STATE.md"),
            "HNGH_REPORT_ROOT": str(self.tmp),
            "HNGH_HOME": str(KERNEL),
            "HNGH_NOTIFY_EMAIL_CONF": str(self.tmp / "absent" / "notify-email.conf"),
            "JOB_NAME": "test-cap-block-operator-item",
            "ITEM_IDENTITY": IDENTITY,
            "ITEM_TEXT": TEXT,
        }

    def file_item(self):
        script = (
            '. "%s/lib/breadcrumbs.sh"\n'
            '. "%s/lib/notify-email.sh"\n'
            '. "%s/lib/operator-item.sh"\n'
            'operator_item "$ITEM_IDENTITY" "$ITEM_TEXT"\n'
            % (ROOT, ROOT, ROOT)
        )
        return subprocess.run(["bash", "-c", script], env=self.env,
                              capture_output=True, text=True, timeout=60)

    def report_rows(self):
        md = (self.tmp / "docs" / "project" / "reports.md").read_text()
        rows = []
        for line in md.splitlines():
            line = line.strip()
            if line.startswith("|") and line.endswith("|"):
                cells = [c.strip() for c in line.strip("|").split("|")]
                if len(cells) == 5 and cells[0] != "timestamp":
                    rows.append(cells)
        return rows

    def test_filed_item_lands_and_parses(self):
        proc = self.file_item()
        self.assertEqual(proc.returncode, 0, proc.stderr)

        # 1. the alert row landed in the seamed report ledger
        rows = self.report_rows()
        self.assertEqual(len(rows), 1, rows)
        ts, kind, rid, first, body_name = rows[0]
        self.assertEqual(kind, "alert")
        self.assertEqual(rid, sha8(TEXT))
        self.assertEqual(first, TEXT)

        # 2. the body file exists and carries the dedup identity
        body = self.tmp / "docs" / "project" / "report-bodies" / body_name
        self.assertTrue(body.is_file(), body_name)
        self.assertIn("- **identity:** %s" % IDENTITY, body.read_text())

        # 3. the ledger parses through the consumer's own read path
        out = subprocess.run(
            ["python3", str(KERNEL / "scripts" / "report-queue"), "--json"],
            env=self.env, capture_output=True, text=True, timeout=60)
        self.assertEqual(out.returncode, 0, out.stderr)
        payload = json.loads(out.stdout)
        self.assertEqual(payload["summary"].get("alert"), 1)
        self.assertEqual(payload["reports"][0]["kind"], "alert")
        self.assertEqual(payload["reports"][0]["first"], TEXT)

        # 4. the STATE.md crumb is what jobs/operator-items-feed.py
        #    crumbs() + is_operator_item() would surface as an item
        crumbs = []
        for line in (self.tmp / "STATE.md").read_text().splitlines():
            parts = [p.strip() for p in line.split(" | ", 3)]
            if len(parts) == 4:
                crumbs.append(parts)
        alerts = [c for c in crumbs if c[2] == "alert"]
        self.assertEqual(len(alerts), 1, crumbs)
        _ts, _job, event, detail = alerts[0]
        self.assertEqual(detail, TEXT)
        self.assertTrue(
            re.match(r"alert", event, re.I) or KEYWORD_RE.search(event + " " + detail),
            "filed crumb must satisfy the operator-items feed criterion")

    def test_same_day_refile_dedups_not_duplicates(self):
        self.file_item()
        self.file_item()
        rows = self.report_rows()
        self.assertEqual(len(rows), 1, rows)
        self.assertTrue(rows[0][3].endswith("\u00d72"), rows[0])
        body = self.tmp / "docs" / "project" / "report-bodies" / rows[0][4]
        self.assertEqual(body.read_text().count("occurrence"), 1)


if __name__ == "__main__":
    unittest.main()
