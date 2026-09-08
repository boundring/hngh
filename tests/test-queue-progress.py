#!/usr/bin/env python3
"""Queue-progress section of email-digest, hermetic.

The delta parser and the kernel queue.md counter run against env-seam
fixtures only (HNGH_DIGEST_PLANS / HNGH_DIGEST_PREV_DIGEST /
HNGH_DIGEST_QUEUE) — never the real dashboard or kernel files.
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIGEST = ROOT / "scripts" / "email-digest.py"

QUEUE_MD = """# Queue — rotating long-term work

prose line with the word queued but no tabs — never counted

```
id\tstatus\ttitle\tevidence
row-a\tqueued\tA\tev
row-b\tdone\tB\tev
row-c\tqueued\tC\tev
```
"""


class QueueProgress(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.plans = self.tmp / "plans.json"
        self.queue = self.tmp / "queue.md"
        self.queue.write_text(QUEUE_MD)
        self.base_env = dict(
            os.environ,
            HNGH_AUTOMATION_ROOT=str(self.tmp),
            HNGH_DIGEST_QUEUE=str(self.queue),
            HNGH_DIGEST_TELEMETRY="t",
            HNGH_DIGEST_ALERTS="",
            HNGH_DIGEST_STORE_DIR=str(self.tmp / "empty-store"),
            HNGH_DIGEST_KERNEL_COMMITS="",
            HNGH_DIGEST_AUTO_COMMITS="",
            HNGH_DIGEST_RESEARCH="",
            HNGH_DIGEST_PLANS=str(self.plans),
        )

    def set_plans(self, plans):
        self.plans.write_text(json.dumps({"plans": plans}))

    def digest(self, **extra):
        return subprocess.run(
            [sys.executable, str(DIGEST)], env=dict(self.base_env, **extra),
            capture_output=True, text=True, timeout=60)

    def section(self, out):
        body = out.split("## Progress (plans + queue, 24h)", 1)[1]
        return body.split("## ", 1)[0]

    def test_first_digest_when_yesterday_missing(self):
        self.set_plans([{"slug": "p-live", "status": "accepted", "risk": "normal",
                         "steps_total": 4, "steps_done": 2}])
        out = self.digest(HNGH_DIGEST_PREV_DIGEST=str(self.tmp / "absent.md")).stdout
        sec = self.section(out)
        self.assertIn("(first digest)", sec)
        self.assertIn("p-live", sec)
        self.assertIn("steps 2/4", sec)
        self.assertIn("kernel queue: 2 queued rows", sec)  # header + fences skipped
        self.assertIn("plan-supply: 1 accepted plans with unchecked steps", sec)

    def test_delta_vs_previous_digest(self):
        self.set_plans([{"slug": "p-live", "status": "accepted", "risk": "normal",
                         "steps_total": 4, "steps_done": 3}])
        prev = self.tmp / "prev.md"
        prev.write_text(
            "## Plan progress (live plans)\n"
            "  p-live                 accepted  steps 2/4 (+0)\n"
            "  p-gone                 proposed  steps 0/5 (+0)\n")
        sec = self.section(self.digest(HNGH_DIGEST_PREV_DIGEST=str(prev)).stdout)
        self.assertIn("steps 3/4 (+1)", sec)   # done advanced 2 -> 3
        self.assertNotIn("p-gone", sec)        # no longer live: not listed
        self.assertNotIn("(first digest)", sec)

    def test_negative_and_new_deltas(self):
        self.set_plans([
            {"slug": "p-regress", "status": "accepted", "risk": "normal",
             "steps_total": 4, "steps_done": 1},
            {"slug": "p-fresh", "status": "accepted", "risk": "normal",
             "steps_total": 2, "steps_done": 0}])
        prev = self.tmp / "prev.md"
        prev.write_text(
            "  p-regress              accepted  steps 3/4\n")
        sec = self.section(self.digest(HNGH_DIGEST_PREV_DIGEST=str(prev)).stdout)
        self.assertIn("steps 1/4 (-2)", sec)
        self.assertIn("p-fresh", sec)
        self.assertIn("(new)", sec)

    def test_no_live_plans_still_reports_counts(self):
        self.set_plans([{"slug": "p-done", "status": "executed", "risk": "normal",
                         "steps_total": 3, "steps_done": 3}])
        sec = self.section(self.digest(
            HNGH_DIGEST_PREV_DIGEST=str(self.tmp / "absent.md")).stdout)
        self.assertIn("(all plans executed/rejected)", sec)
        self.assertIn("plan-supply: 0 accepted plans with unchecked steps", sec)

    def test_held_plan_is_visible_but_not_supply(self):
        self.set_plans([{"slug": "p-held", "status": "held", "risk": "normal",
                         "steps_total": 2, "steps_done": 0}])
        sec = self.section(self.digest(
            HNGH_DIGEST_PREV_DIGEST=str(self.tmp / "absent.md")).stdout)
        self.assertIn("p-held", sec)                # still listed as live
        self.assertIn("held (missing design)", sec)
        self.assertIn("plan-supply: 0 accepted plans with unchecked steps", sec)

    def test_unreadable_inputs_degrade(self):
        sec = self.section(self.digest(
            HNGH_DIGEST_PLANS="/nonexistent.json",
            HNGH_DIGEST_QUEUE="/nonexistent-queue.md",
            HNGH_DIGEST_PREV_DIGEST=str(self.tmp / "absent.md")).stdout)
        self.assertIn("(plans.json unreadable)", sec)
        self.assertIn("kernel queue: unreadable", sec)

    def test_pace_zero_steps_with_pending_is_stalling(self):
        # rubric fix (2026-09-04 digest): 0 ticks + pending work is NOT
        # steady — the honest verdict is stalling with the pending count
        self.set_plans([{"slug": "p-live", "status": "accepted",
                         "risk": "normal", "steps_total": 4,
                         "steps_done": 2}])
        prev = self.tmp / "prev.md"
        prev.write_text("  p-live                        accepted  "
                        "steps 2/4\n")
        sec = self.section(self.digest(
            HNGH_DIGEST_PREV_DIGEST=str(prev)).stdout)
        self.assertIn("pace: stalling (0 steps in 24h; 1 plans pending)", sec)

    def test_pace_zero_without_pending_is_idle(self):
        self.set_plans([{"slug": "p-done", "status": "executed",
                         "risk": "normal", "steps_total": 3,
                         "steps_done": 3}])
        prev = self.tmp / "prev.md"
        prev.write_text("  p-done                        executed  "
                        "steps 3/3\n")
        sec = self.section(self.digest(
            HNGH_DIGEST_PREV_DIGEST=str(prev)).stdout)
        self.assertIn("pace: idle (queue empty)", sec)

    def test_routed_one_steppers_line(self):
        import datetime as dt
        today = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%d")
        yday = (dt.datetime.now(dt.timezone.utc)
                - dt.timedelta(days=1)).strftime("%Y-%m-%d")
        self.set_plans([
            {"slug": today + "-routed-agent-stall-x", "status": "accepted",
             "risk": "normal", "steps_total": 1, "steps_done": 0},
            {"slug": yday + "-routed-agent-stall-y", "status": "accepted",
             "risk": "normal", "steps_total": 1, "steps_done": 0},
            {"slug": yday + "-routed-review-z", "status": "executed",
             "risk": "normal", "steps_total": 1, "steps_done": 1},
            # out of window / not a one-stepper / not routed: not counted
            {"slug": "2026-08-30-routed-old", "status": "accepted",
             "risk": "normal", "steps_total": 1, "steps_done": 0},
            {"slug": today + "-routed-multi", "status": "accepted",
             "risk": "normal", "steps_total": 9, "steps_done": 0},
        ])
        sec = self.section(self.digest(
            HNGH_DIGEST_PREV_DIGEST=str(self.tmp / "absent.md")).stdout)
        self.assertIn("routed one-steppers: 2 accepted, 1 executed (24h)",
                      sec)


if __name__ == "__main__":
    unittest.main()
