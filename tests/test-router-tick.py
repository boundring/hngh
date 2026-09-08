#!/usr/bin/env python3
"""Router-tick contract, hermetic (routing doc, "Outcome tracking
without kernel changes (2026-08-31)"): a closed-step re-fire is skipped
with exactly one observable pair (STATE.md breadcrumb + deduped
router:dup-skip alert row); an open-step re-fire marks in-flight
without re-drafting; a first fire drafts a proposed candidate tagged
routed-from=<identity> plus its router:routed row; critical classes
park. The tagged candidate round-trips accept-plans.py (DRY_RUN=1)
and jobs/plan-feed.py without parse error.
"""

import json
import os
import time
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TICK = ROOT / "scripts" / "router-tick.py"
DISPOSE = ROOT / "scripts" / "plan-dispose.py"
ACCEPT = ROOT / "scripts" / "accept-plans.py"
PLAN_FEED = ROOT / "jobs" / "plan-feed.py"


def accepted_plan(steps, status="accepted"):
    """steps: list of boxes, e.g. ('x', ' ')."  """
    lines = ["<!-- plan: status=%s risk=normal " % status +
             "accepted=2026-08-31T22:01:21Z -->", "", "# fixture plan",
             "", "## Steps", ""]
    for i, box in enumerate(steps, 1):
        lines.append("- [%s] step %d" % (box, i))
        lines.append("      Verification: fixture check %d" % i)
        lines.append("")
    return "\n".join(lines)


class RouterTick(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name)
        self.kernel = self.root / "kernel"
        self.plans = self.kernel / "docs" / "project" / "plans"
        self.plans.mkdir(parents=True)
        self.auto = self.root / "auto"
        self.auto.mkdir()
        # stub gates for the accept-plans round-trip (exit 0, log cwd)
        self.gate = self.root / "gate.sh"
        self.gate.write_text(
            "#!/usr/bin/env bash\n"
            "printf '%s\\n' \"$1 $PWD\" >> " + str(self.root / "gate.log") + "\n"
            "exit \"$1\"\n")
        self.gate.chmod(0o755)
        # stub report-queue: record argv
        self.queue = self.root / "queue.sh"
        self.queue.write_text(
            "#!/usr/bin/env bash\n"
            "printf '%s\\n' \"$*\" >> " + str(self.root / "queue.log") + "\n")
        self.queue.chmod(0o755)
        self.state = self.root / "STATE.md"
        self.env = {
            **os.environ,
            "HNGH_HOME": str(self.kernel),
            "HNGH_AUTOMATION_ROOT": str(self.auto),
            "HNGH_REPORT_QUEUE": str(self.queue),
            "HNGH_REPORT_ROOT": str(self.kernel),
            "STATE_FILE": str(self.state),
            "HNGH_PLANS_FEED_OUT": str(self.root / "plans.json"),
        }

    def tearDown(self):
        self._td.cleanup()

    def run_tick(self, identity, text="", dedup_hours=None, dry=None):
        return self.tick_env(identity, text, dedup_hours, dry)

    def tick_env(self, identity, text="", dedup_hours=None, dry=None):
        return subprocess.run(
            [sys.executable, str(TICK), "--identity", identity, "--text", text],
            env={**self.env,
                 **({"HNGH_ROUTER_DEDUP_HOURS": dedup_hours}
                    if dedup_hours else {}),
                 **({"DRY_RUN": dry} if dry else {})},
            capture_output=True, text=True)

    def rows(self):
        log = self.root / "queue.log"
        return log.read_text().splitlines() if log.exists() else []

    def breadcrumbs(self):
        return (self.state.read_text().splitlines()
                if self.state.exists() else [])

    def candidates(self):
        return sorted(p.name for p in self.plans.glob("*routed*.plan.md"))

    def test_closed_step_refire_files_duplicate_skip_pair(self):
        self.plans.joinpath("2026-08-31-x.plan.md").write_text(
            accepted_plan("x "))
        out = self.run_tick("gate:plan:2026-08-31-x:step-1")
        self.assertEqual(out.returncode, 0, out.stderr)
        # exactly one row: the dup-skip alert, never a candidate add
        rows = self.rows()
        self.assertEqual(len(rows), 1, rows)
        self.assertIn("alert", rows[0])
        self.assertIn("--identity router:dup-skip:gate:plan:2026-08-31-x:step-1",
                      rows[0])
        self.assertIn("--window 86400", rows[0])
        self.assertIn("named step closed; candidate not re-drafted", rows[0])
        # the pair's breadcrumb leg
        self.assertTrue(any(
            "| router | duplicate-skip | "
            "gate:plan:2026-08-31-x:step-1 step already closed" in b
            for b in self.breadcrumbs()), self.breadcrumbs())
        self.assertEqual(self.candidates(), [])  # no re-draft

    def test_open_step_refire_marks_in_flight(self):
        self.plans.joinpath("2026-08-31-x.plan.md").write_text(
            accepted_plan("x "))
        out = self.run_tick("gate:plan:2026-08-31-x:step-2")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertEqual(self.candidates(), [])
        self.assertTrue(any("router:routed:2026-08-31-x:step-2" in r
                            and "still open" in r for r in self.rows()),
                        self.rows())
        self.assertTrue(any("| router | in-flight |" in b
                            for b in self.breadcrumbs()))
        self.assertFalse(any("duplicate-skip" in r for r in self.rows()))

    def test_first_fire_drafts_tagged_candidate(self):
        out = self.run_tick("gate-red:kernel-red", "kernel make test failed")
        self.assertEqual(out.returncode, 0, out.stderr)
        cands = self.candidates()
        self.assertEqual(len(cands), 1, cands)
        text = (self.plans / cands[0]).read_text()
        self.assertIn("status=proposed risk=normal accepted=- "
                      "routed-from=gate-red:kernel-red -->", text)
        # gate identities are knowledge-shaped: they route to a
        # research-demand candidate (disposition spine), not a bare re-run
        self.assertIn("- [ ] Delve: open research subject fail-", text)
        self.assertIn("record disposition; then fix or park", text)
        self.assertRegex(text, r"(?m)^      Verification: ")
        self.assertTrue(any("progress" in r and "router:routed:" in r
                            and "--window 86400" in r for r in self.rows()),
                        self.rows())
        self.assertTrue(any("| router | routed | gate-red:kernel-red -> " in b
                            for b in self.breadcrumbs()))

    def test_critical_class_parks_without_candidate(self):
        out = self.run_tick("remote-posture:degraded")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertEqual(self.candidates(), [])
        self.assertTrue(any("alert" in r
                            and "router:parked:remote-posture:degraded" in r
                            for r in self.rows()), self.rows())
        self.assertTrue(any("| router | parked |" in b
                            for b in self.breadcrumbs()))

    def test_tagged_candidate_round_trips_parsers(self):
        self.run_tick("gate-red:kernel-red", "kernel make test failed")
        cand = self.candidates()[0]
        slug = cand[:-len(".plan.md")]
        env = {**self.env, "DRY_RUN": "1",
               "ACCEPT_KERNEL_GATE": "%s 0" % self.gate,
               "ACCEPT_AUTOMATION_GATE": "%s 0" % self.gate,
               "ACCEPT_LOG": str(self.root / "acceptance.log")}
        accept = subprocess.run([sys.executable, str(ACCEPT)], env=env,
                                capture_output=True, text=True)
        self.assertEqual(accept.returncode, 0, accept.stderr)
        self.assertIn("accepted %s" % slug, accept.stdout)  # parses + runnable
        feed = subprocess.run([sys.executable, str(PLAN_FEED)], env=self.env,
                              capture_output=True, text=True)
        self.assertEqual(feed.returncode, 0, feed.stderr)
        plans = json.loads((self.root / "plans.json").read_text())["plans"]
        mine = [p for p in plans if p["slug"] == slug]
        self.assertEqual(len(mine), 1, plans)
        self.assertEqual(mine[0]["status"], "proposed")
        self.assertEqual(mine[0]["steps_total"], 1)
        self.assertEqual(mine[0]["steps_done"], 0)
        # DRY_RUN never flipped the file
        self.assertIn("status=proposed",
                      (self.plans / cand).read_text())

    def test_refire_naming_missing_plan_files_nothing(self):
        out = self.run_tick("gate:plan:2026-08-31-missing:step-1")
        self.assertEqual(out.returncode, 0)
        self.assertEqual(self.rows(), [])
        self.assertTrue(any("| router | no-candidate |" in b
                            for b in self.breadcrumbs()))

    def routed(self, ident, steps=" ", status="accepted", age_s=0, day=None):
        """A routed plan fixture for `ident` with a given status/age."""
        day = day or "2026-09-03"
        slug = "%s-routed-%s" % (day, ident.replace(":", "-"))
        p = self.plans.joinpath(slug + ".plan.md")
        p.write_text(accepted_plan(steps, status=status))
        if age_s:
            t = time.time() - age_s
            os.utime(p, (t, t))
        return p

    def test_live_duplicate_suppresses_candidate_keeps_signal(self):
        p = self.routed("agent-stall-omp-impl-9d5ab9", age_s=3600)  # 1h old
        out = self.run_tick("agent-stall:omp-impl-9d5ab9", "stalled")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertEqual(self.candidates(), [p.name])  # no duplicate drafted
        # the alert signal still lands in reports.md (deduped daily)
        self.assertTrue(any("alert" in r
                            and "router:dedup:agent-stall:omp-impl-9d5ab9"
                            in r for r in self.rows()), self.rows())
        self.assertTrue(any("| router | plan-dedup |" in b
                            for b in self.breadcrumbs()))

    def test_terminal_duplicate_routes_fresh_suffixed(self):
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        old = self.routed("agent-stall-omp-impl-9d5ab9", steps="x ",
                          status="executed", age_s=60,
                          day=today)
        out = self.run_tick("agent-stall:omp-impl-9d5ab9", "stalled again")
        self.assertEqual(out.returncode, 0, out.stderr)
        cands = self.candidates()
        self.assertEqual(len(cands), 2, cands)
        fresh = [c for c in cands if c != old.name]
        self.assertRegex(fresh[0], r"-routed-agent-stall-omp-impl-9d5ab9-2\.plan\.md$")
        self.assertIn("status=proposed", (self.plans / fresh[0]).read_text())

    def test_suffixed_live_duplicate_suppresses_candidate(self):
        """A live -N routed plan counts as a duplicate: the router must
        not draft a fresh candidate per hourly fire (the 2026-09-05
        tree-skew-hngh-2..-9 hourly spam)."""
        old = self.routed("tree-skew-hngh", steps="x ",
                          status="executed", age_s=60)
        live = self.plans.joinpath("2026-09-03-routed-tree-skew-hngh-2.plan.md")
        live.write_text(accepted_plan(" "))
        t = time.time() - 600
        os.utime(live, (t, t))
        out = self.run_tick("tree-skew:hngh", "skewed")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertEqual(self.candidates(), sorted([old.name, live.name]))
        self.assertTrue(any("alert" in r
                            and "router:dedup:tree-skew:hngh" in r
                            for r in self.rows()), self.rows())

    def test_dedup_window_boundary_and_seam(self):
        p = self.routed("gate-red-kernel", age_s=3 * 3600)  # 3h old
        # inside a 12h window: suppressed
        out = self.run_tick("gate-red:kernel", "")
        self.assertEqual(self.candidates(), [p.name])
        # HNGH_ROUTER_DEDUP_HOURS=2: 3h is past the window -> routes fresh
        out = self.run_tick("gate-red:kernel", "", dedup_hours="1")
        self.assertEqual(len(self.candidates()), 2)

    def test_dedup_escalates_at_three_per_day(self):
        self.routed("agent-stall-omp-impl-9d5ab9", age_s=600)
        for _ in range(3):  # count reaches 3 on the third dedup
            self.run_tick("agent-stall:omp-impl-9d5ab9", "stalled")
        self.assertTrue(any("router:dedup-escalated:"
                            "agent-stall:omp-impl-9d5ab9" in r
                            and "escalated to operator visibility" in r
                            for r in self.rows()), self.rows())
        self.assertEqual(sum(1 for r in self.rows()
                             if "dedup-escalated" in r), 1)

    def test_dry_run_decides_but_writes_nothing(self):
        p = self.routed("agent-stall-omp-impl-9d5ab9", age_s=600)
        out = self.run_tick("agent-stall:omp-impl-9d5ab9", "stalled",
                            dry="1")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("dedup", out.stdout)
        self.assertEqual(self.candidates(), [p.name])
        self.assertEqual(self.rows(), [])
        self.assertEqual(self.breadcrumbs(), [])

    def test_same_identity_bumps_occurrences_in_place(self):
        """The 2026-09-05 tree-skew failure: a live same-identity plan
        must absorb the re-occurrence in place, never mint a twin."""
        p = self.routed("tree-skew-hngh", steps=" ", status="proposed",
                        age_s=600)
        out = self.run_tick("tree-skew:hngh", "skewed")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertEqual(self.candidates(), [p.name])  # no new file
        text = p.read_text()
        self.assertIn("## Occurrences", text)
        self.assertEqual(text.count("re-occurred (dedup window expired)"), 1)
        self.assertIn("status=proposed", text)  # untouched by the bump
        self.run_tick("tree-skew:hngh", "skewed again")
        self.assertEqual(
            p.read_text().count("re-occurred (dedup window expired)"), 2)

    def test_threshold_parks_zero_progress_plan(self):
        p = self.routed("tree-skew-hngh", steps=" ", status="proposed",
                        age_s=600)
        p.write_text(p.read_text()
                     + "\n## Occurrences\n\n- earlier occurrence\n")
        self.run_tick("tree-skew:hngh", "skewed")  # 1 prior + 1 = 2 < 3
        self.assertIn("status=proposed", p.read_text())
        self.run_tick("tree-skew:hngh", "skewed")  # 3rd occurrence: parks
        text = p.read_text()
        self.assertIn("status=parked", text)
        self.assertIn("cause=obsolete", text)
        self.assertIn("reason=identity re-occurred 3 times without landing",
                      text)
        self.assertTrue(any("alert" in r and "router:parked:tree-skew:hngh"
                            in r for r in self.rows()), self.rows())
        self.assertTrue(any("| router | escalated-park |" in b
                            for b in self.breadcrumbs()))

    def test_accepted_in_progress_never_parked_or_bumped(self):
        p = self.routed("tree-skew-hngh", steps="x ", status="accepted",
                        age_s=600)
        for _ in range(3):
            out = self.run_tick("tree-skew:hngh", "skewed")
            self.assertEqual(out.returncode, 0, out.stderr)
        text = p.read_text()
        self.assertNotIn("## Occurrences", text)
        self.assertIn("status=accepted", text)
        self.assertFalse(any("router:parked:" in r for r in self.rows()),
                         self.rows())


class PlanDispose(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.plans = Path(self._td.name) / "docs" / "project" / "plans"
        self.plans.mkdir(parents=True)
        self.env = {**os.environ, "HNGH_HOME": str(self.plans.parents[2])}

    def tearDown(self):
        self._td.cleanup()

    def run_dispose(self, *args):
        return subprocess.run(
            [sys.executable, str(DISPOSE), *args],
            env=self.env, capture_output=True, text=True)

    def fixture(self, status="proposed", name="2026-09-03-routed-x.plan.md"):
        p = self.plans / name
        p.write_text(accepted_plan(" ", status=status))
        return p

    def test_park_rewrites_header_preserving_fields(self):
        p = self.fixture()
        out = self.run_dispose(p.name, "--action", "park",
                               "--cause", "obsolete", "--reason", "dead end")
        self.assertEqual(out.returncode, 0, out.stderr)
        text = p.read_text()
        self.assertIn("status=parked risk=normal", text)
        self.assertIn("cause=obsolete disposed=", text)
        self.assertIn("reason=dead end -->", text)
        self.assertRegex(text, r"disposed=\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z")

    def test_bare_plan_id_resolves_with_suffix(self):
        p = self.fixture()
        out = self.run_dispose("2026-09-03-routed-x", "--action", "kill",
                               "--cause", "bad-execution", "--reason", "r")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("status=killed", p.read_text())

    def test_refuses_unknown_action_and_cause(self):
        p = self.fixture()
        out = self.run_dispose(p.name, "--action", "nuke",
                               "--cause", "obsolete", "--reason", "r")
        self.assertEqual(out.returncode, 2)
        self.assertIn("unknown action", out.stderr)
        out = self.run_dispose(p.name, "--action", "park",
                               "--cause", "vibes", "--reason", "r")
        self.assertEqual(out.returncode, 2)
        self.assertIn("unknown cause class", out.stderr)
        self.assertIn("status=proposed", p.read_text())  # untouched

    def test_refuses_terminal_plan_unchanged(self):
        for status in ("executed", "rejected", "parked"):
            p = self.fixture(status=status)
            out = self.run_dispose(p.name, "--action", "park",
                                   "--cause", "obsolete", "--reason", "r")
            self.assertEqual(out.returncode, 2, out.stderr)
            self.assertIn("already terminal", out.stderr)
            self.assertIn("status=%s" % status, p.read_text())

    def test_refuses_missing_file_and_escape(self):
        out = self.run_dispose("2026-09-03-routed-missing", "--action",
                               "park", "--cause", "obsolete", "--reason", "r")
        self.assertEqual(out.returncode, 2)
        self.assertIn("no plan file found", out.stderr)
        out = self.run_dispose(os.path.join(self.plans.parent, "x.plan.md"),
                               "--action", "park", "--cause", "obsolete",
                               "--reason", "r")
        self.assertEqual(out.returncode, 2)
        self.assertIn("no plan file found", out.stderr)


if __name__ == "__main__":
    unittest.main()
