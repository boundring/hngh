#!/usr/bin/env python3
"""Router-feed wiring contract, hermetic (2026-09-01-overnight-continuity
step 2): cadence/hour/10-router-feed.sh is the first production caller of
scripts/router-tick.py. A seeded unread alert row reaching the tick THROUGH
the drop-in files the observable pair (STATE.md breadcrumb + report-queue
row); a closed-step re-fire dup-skips without a candidate; a re-feed of a
still-unread row bumps the one deduped row instead of appending; excluded
classes (critical regex, router:*, overnight:critical-touch:*, charset
failures) never reach the tick; the newest-first feed is capped at
ROUTER_FEED_MAX; ROUTER_FEED_ONLY scopes a run. Uses the REAL
scripts/report-queue copied into a temp kernel, so the identity grammar
and window dedup are exercised for real — no network, no real-ledger
writes, no systemd.
"""

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FEED = ROOT / "cadence" / "hour" / "10-router-feed.sh"
REAL_REPORT_QUEUE = ROOT.parent / "scripts" / "report-queue"


def accepted_plan(steps):
    """steps: list of boxes, e.g. ('x', ' ')."""
    lines = ["<!-- plan: status=accepted risk=normal "
             "accepted=2026-08-31T22:01:21Z -->", "", "# fixture plan",
             "", "## Steps", ""]
    for i, box in enumerate(steps, 1):
        lines.append("- [%s] step %d" % (box, i))
        lines.append("      Verification: fixture check %d" % i)
        lines.append("")
    return "\n".join(lines)


class RouterFeed(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name)
        self.kernel = self.root / "kernel"
        self.plans = self.kernel / "docs" / "project" / "plans"
        self.plans.mkdir(parents=True)
        (self.kernel / "scripts").mkdir()
        shutil.copy(REAL_REPORT_QUEUE,
                    self.kernel / "scripts" / "report-queue")
        self.state = self.root / "STATE.md"
        self.env = {
            **os.environ,
            "HNGH_HOME": str(self.kernel),
            "HNGH_REPORT_ROOT": str(self.kernel),
            "STATE_FILE": str(self.state),
        }

    def tearDown(self):
        self._td.cleanup()

    def rq(self, *args):
        return subprocess.run(
            [sys.executable, str(self.kernel / "scripts" / "report-queue"),
             *args],
            env={**os.environ, "HNGH_REPORT_ROOT": str(self.kernel)},
            capture_output=True, text=True)

    def seed(self, identity, text="wired alert"):
        # distinct text per row: report-queue ids are sha8(TEXT) and body
        # files share {ts}-{kind}-{rid}.md, so same-second same-text seeds
        # would overwrite one body file (one identity for all rows)
        if text == "wired alert":
            text = "wired alert %s" % identity
        out = self.rq("--add", "alert", text,
                      "--identity", identity, "--window", "86400")
        self.assertEqual(out.returncode, 0, out.stderr)

    def run_feed(self, **extra):
        env = {**self.env, **{k: str(v) for k, v in extra.items()}}
        return subprocess.run(["bash", str(FEED)], env=env,
                              capture_output=True, text=True)

    def ledger_lines(self):
        rep = self.kernel / "docs" / "project" / "reports.md"
        return rep.read_text().splitlines() if rep.exists() else []

    def bodies(self):
        d = self.kernel / "docs" / "project" / "report-bodies"
        if not d.exists():
            return ""
        return "".join(p.read_text() for p in d.glob("*.md"))

    def breadcrumbs(self):
        return (self.state.read_text().splitlines()
                if self.state.exists() else [])

    def candidates(self):
        return sorted(p.name for p in self.plans.glob("*routed*.plan.md"))

    def dup_skip_rows(self, ident):
        return [ln for ln in self.ledger_lines()
                if "router duplicate-skip: %s" % ident in ln]

    def test_closed_step_refire_through_feed_files_skip_pair(self):
        ident = "gate-check:plan:2026-08-30-fixture:step-1"
        self.plans.joinpath("2026-08-30-fixture.plan.md").write_text(
            accepted_plan("x "))
        self.seed(ident, "router-feed wiring demo: re-fire of a closed step")
        out = self.run_feed()
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("**identity:** router:dup-skip:%s" % ident,
                      self.bodies())
        self.assertTrue(any(
            "| router | duplicate-skip | %s step already closed" % ident
            in b for b in self.breadcrumbs()), self.breadcrumbs())
        self.assertEqual(self.candidates(), [])  # no re-draft
        self.assertTrue(any("| router-feed | fed | 1 identity(ies): %s "
                            % ident in b for b in self.breadcrumbs()))

    def test_refeed_of_still_unread_row_bumps_one_row(self):
        ident = "gate-check:plan:2026-08-30-fixture:step-1"
        self.plans.joinpath("2026-08-30-fixture.plan.md").write_text(
            accepted_plan("x "))
        self.seed(ident)
        self.assertEqual(self.run_feed().returncode, 0)
        self.assertEqual(self.run_feed().returncode, 0)
        rows = self.dup_skip_rows(ident)
        self.assertEqual(len(rows), 1, rows)  # one deduped row, not two
        self.assertIn("×2", rows[0], rows)    # occurrence folded in
        self.assertEqual(self.candidates(), [])

    def test_excluded_classes_never_reach_the_tick(self):
        for ident in ("budget:weekly-cap",                      # critical
                      "router:routed:2026-08-30-x",             # self-feedback
                      "overnight:critical-touch:plan-x",        # operator
                      "stale-store:/tmp/hngh-cer-x",            # charset
                      "review:hngh:P1-finding"):                # routable
            self.seed(ident)
        out = self.run_feed()
        self.assertEqual(out.returncode, 0, out.stderr)
        cands = self.candidates()
        self.assertEqual(len(cands), 1, cands)
        self.assertIn("review-hngh-P1-finding", cands[0])
        self.assertIn("routed-from=review:hngh:P1-finding",
                      (self.plans / cands[0]).read_text())
        crumbs = "\n".join(self.breadcrumbs())
        for noise in ("budget:weekly-cap", "router:routed:",
                      "overnight:critical-touch", "stale-store:",
                      "| router | parked |"):
            self.assertNotIn(noise, crumbs)

    def test_cap_limits_identities_per_invocation(self):
        for ident in ("review:a1", "review:a2", "review:a3",
                      "tree-skew:b", "ui-audit:c"):
            self.seed(ident)
        out = self.run_feed(ROUTER_FEED_MAX=2)
        self.assertEqual(out.returncode, 0, out.stderr)
        cands = self.candidates()
        self.assertEqual(len(cands), 2, cands)
        # newest-first cap: the two most recently seeded identities route,
        # the three older review ones starve behind the cap
        joined = " ".join(cands)
        self.assertIn("ui-audit-c", joined, cands)
        self.assertIn("tree-skew-b", joined, cands)
        self.assertNotIn("review-a", joined, cands)

    def test_only_filter_scopes_a_run(self):
        self.seed("review:hngh:P1-finding")
        self.seed("tree-skew:hngh")
        out = self.run_feed(ROUTER_FEED_ONLY="^review:")
        self.assertEqual(out.returncode, 0, out.stderr)
        cands = self.candidates()
        self.assertEqual(len(cands), 1, cands)
        self.assertIn("review-hngh-P1-finding", cands[0])


if __name__ == "__main__":
    unittest.main()
