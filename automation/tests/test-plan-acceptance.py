#!/usr/bin/env python3
"""Machine plan acceptance + plans feed contract, hermetic.

Everything runs in a disposable temp root: fixture plans, stub gate
scripts, a stub report-queue recorder. No real `make test`, no real
kernel plans, no plan step is ever executed.
Contract (hngh docs/project/plans/README.md): a proposed normal-risk
plan is auto-accepted only when every unchecked step carries a
Verification line and both gates are green; critical plans park;
blocked acceptances file an alert naming the failed check.
"""

import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ACCEPT = ROOT / "scripts" / "accept-plans.py"
PLAN_FEED = ROOT / "jobs" / "plan-feed.py"

TS = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z")


def plan_md(steps, status="proposed", risk="normal", accepted="-"):
    """steps: list of (box, text, verification|None)."""
    lines = ["<!-- plan: status=%s risk=%s accepted=%s -->" %
             (status, risk, accepted), "", "# fixture plan", "",
             "## Steps", ""]
    for i, (box, text, ver) in enumerate(steps, 1):
        lines.append("- [%s] step %d: %s" % (box, i, text))
        if ver:
            lines.append("      Verification: %s" % ver)
        lines.append("")
    return "\n".join(lines)


class AcceptPlans(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name)
        self.kernel = self.root / "kernel"
        self.plans = self.kernel / "docs" / "project" / "plans"
        self.plans.mkdir(parents=True)
        self.auto = self.root / "auto"
        self.auto.mkdir()
        # stub gates: exit the rc given as $1, log "rc PWD"
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
        self.env = {
            **os.environ,
            "DRY_RUN": "0",  # ambient DRY_RUN must not skew the suite
            "HNGH_HOME": str(self.kernel),
            "HNGH_AUTOMATION_ROOT": str(self.auto),
            "ACCEPT_KERNEL_GATE": "%s 0" % self.gate,
            "ACCEPT_AUTOMATION_GATE": "%s 0" % self.gate,
            "HNGH_REPORT_QUEUE": str(self.queue),
            "HNGH_REPORT_ROOT": str(self.kernel),
            "ACCEPT_LOG": str(self.root / "acceptance.log"),
            "HNGH_RESEARCH_SUBJECTS": str(self.root / "research-subjects.txt"),
            "GATE_RC_UNUSED": "",  # keep env stable across runs
        }
        del self.env["GATE_RC_UNUSED"]

    def tearDown(self):
        self._td.cleanup()

    def run_accept(self, **extra):
        return subprocess.run([sys.executable, str(ACCEPT)],
                              env={**self.env, **extra},
                              capture_output=True, text=True)

    def write_plan(self, name, text):
        (self.plans / name).write_text(text, encoding="utf-8")

    def plan(self, name):
        return (self.plans / name).read_text(encoding="utf-8")

    def rows(self):
        log = self.root / "queue.log"
        return log.read_text().splitlines() if log.exists() else []

    def gate_log(self):
        log = self.root / "gate.log"
        return log.read_text().splitlines() if log.exists() else []

    def test_accepts_runnable_normal_plan(self):
        self.write_plan("2026-08-30-x.plan.md", plan_md(
            [(" ", "do a thing", "bash -n scripts/x.sh"),
             (" ", "do another", "make test")]))
        out = self.run_accept()
        self.assertEqual(out.returncode, 0, out.stderr)
        flipped = self.plan("2026-08-30-x.plan.md")
        self.assertRegex(flipped,
                         r"status=accepted risk=normal accepted=%s" % TS.pattern)
        self.assertIn("- [ ] step 1: do a thing", flipped)  # body untouched
        self.assertIn("accepted 2026-08-30-x", out.stdout)
        # progress row through the report writer
        self.assertTrue(any("progress" in r and "2026-08-30-x" in r
                            and "auto-accepted" in r for r in self.rows()),
                        self.rows())
        # both gates ran, each in its own repo
        pwds = sorted(line.split(" ", 1)[1] for line in self.gate_log())
        self.assertEqual(pwds, [str(self.auto), str(self.kernel)])
        # execution log written
        self.assertIn("accepted 2026-08-30-x",
                      (self.root / "acceptance.log").read_text())

    def test_blocks_step_without_verification(self):
        text = plan_md([(" ", "do a thing", None)])
        self.write_plan("2026-08-30-x.plan.md", text)
        out = self.run_accept()
        self.assertEqual(self.plan("2026-08-30-x.plan.md"), text)  # untouched
        self.assertIn("blocked 2026-08-30-x", out.stdout)
        self.assertTrue(any("alert" in r and "Verification" in r
                            for r in self.rows()), self.rows())
        self.assertEqual(self.gate_log(), [])  # gates not consulted

    def test_blocks_kernel_gate_red(self):
        self.write_plan("2026-08-30-x.plan.md",
                        plan_md([(" ", "do a thing", "make test")]))
        out = self.run_accept(ACCEPT_KERNEL_GATE="%s 1" % self.gate)
        self.assertNotIn("status=accepted", self.plan("2026-08-30-x.plan.md"))
        self.assertIn("blocked 2026-08-30-x kernel-gate-red-rc1", out.stdout)
        self.assertTrue(any("alert" in r and "kernel make test FAILED" in r
                            for r in self.rows()), self.rows())

    def test_blocks_automation_gate_red(self):
        self.write_plan("2026-08-30-x.plan.md",
                        plan_md([(" ", "do a thing", "make test")]))
        out = self.run_accept(ACCEPT_AUTOMATION_GATE="%s 1" % self.gate)
        self.assertNotIn("status=accepted", self.plan("2026-08-30-x.plan.md"))
        self.assertTrue(any("alert" in r and "automation make test FAILED" in r
                            for r in self.rows()), self.rows())

    def test_critical_plan_never_accepted(self):
        text = plan_md([(" ", "do a thing", "make test")], risk="critical")
        self.write_plan("2026-08-30-x.plan.md", text)
        out = self.run_accept()
        self.assertEqual(self.plan("2026-08-30-x.plan.md"), text)
        self.assertIn("parked 2026-08-30-x critical-class", out.stdout)
        self.assertTrue(any("alert" in r and "critical" in r
                            for r in self.rows()), self.rows())
        self.assertEqual(self.gate_log(), [])

    def test_ignores_non_proposed_and_executed(self):
        self.write_plan("2026-08-28-old.plan.md", plan_md(
            [("x", "done", "make test")], status="executed",
            accepted="2026-08-28T00:00:00Z"))
        out = self.run_accept()
        self.assertEqual(out.stdout.strip(), "")
        self.assertEqual(self.rows(), [])
        self.assertEqual(self.gate_log(), [])

    def test_checked_steps_need_no_verification(self):
        self.write_plan("2026-08-30-x.plan.md", plan_md(
            [("x", "done already", None), (" ", "pending", "make test")]))
        out = self.run_accept()
        self.assertIn("accepted 2026-08-30-x", out.stdout)

    def test_dry_run_writes_nothing(self):
        text = plan_md([(" ", "do a thing", "make test")])
        self.write_plan("2026-08-30-x.plan.md", text)
        out = self.run_accept(DRY_RUN="1")
        self.assertIn("accepted 2026-08-30-x", out.stdout)  # would accept
        self.assertEqual(self.plan("2026-08-30-x.plan.md"), text)
        self.assertEqual(self.rows(), [])
        self.assertFalse((self.root / "acceptance.log").exists())

    # --- design gate: grow cannot outrun its designs ----------------------

    def test_accepts_plan_naming_existing_design(self):
        design = self.kernel / "docs" / "design"
        design.mkdir(parents=True)
        (design / "existing-spec.md").write_text("# spec\n")
        self.write_plan("2026-08-30-x.plan.md", plan_md(
            [(" ", "do a thing", "make test")])
            + "\nImplements docs/design/existing-spec.md.\n")
        out = self.run_accept()
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertRegex(self.plan("2026-08-30-x.plan.md"),
                         r"status=accepted")
        self.assertIn("accepted 2026-08-30-x", out.stdout)

    def test_holds_plan_naming_missing_design(self):
        text = plan_md([(" ", "do a thing", "make test")]) \
            + "\nPer docs/design/absent-spec.md, guided by\n" \
              "docs/design/also-absent.md.\n"
        self.write_plan("2026-08-30-x.plan.md", text)
        out = self.run_accept()
        self.assertEqual(out.returncode, 0, out.stderr)
        held = self.plan("2026-08-30-x.plan.md")
        self.assertRegex(held,
                         r"status=held risk=normal accepted=- "
                         r"cause=missing-design held=%s" % TS.pattern)
        self.assertIn("held 2026-08-30-x missing-design:", out.stdout)
        self.assertIn("docs/design/absent-spec.md", out.stdout)
        self.assertTrue(any("design-hold:2026-08-30-x" in r
                            and "delve: produce or locate the design" in r
                            for r in self.rows()), self.rows())
        # research demand wired: one fail-<date>-<slug> subject row
        subj = self.root / "research-subjects.txt"
        lines = subj.read_text().splitlines()
        self.assertEqual(len(lines), 1, lines)
        self.assertRegex(lines[0], r"^fail-\d{8}-2026-08-30-x\t")
        self.assertIn("delve: produce or locate the design", lines[0])
        self.assertEqual(self.gate_log(), [])  # gates not consulted

    def test_vague_design_wording_never_holds(self):
        self.write_plan("2026-08-30-x.plan.md", plan_md(
            [(" ", "do a thing", "make test")])
            + "\nThe interaction needs a design; design pending.\n")
        out = self.run_accept()
        self.assertRegex(self.plan("2026-08-30-x.plan.md"),
                         r"status=accepted")
        self.assertIn("warn 2026-08-30-x vague-design-wording", out.stdout)
        self.assertFalse((self.root / "research-subjects.txt").exists())

    def test_held_plan_reproposes_when_design_lands(self):
        self.write_plan("2026-08-30-x.plan.md", plan_md(
            [(" ", "do a thing", "make test")])
            + "\nPer docs/design/late-spec.md.\n")
        first = self.run_accept()
        self.assertIn("held 2026-08-30-x", first.stdout)
        self.assertRegex(self.plan("2026-08-30-x.plan.md"),
                         r"status=held .*cause=missing-design")
        # design lands; the next gate run re-proposes the plan
        design = self.kernel / "docs" / "design" / "late-spec.md"
        design.parent.mkdir(parents=True)
        design.write_text("# landed\n")
        second = self.run_accept()
        self.assertIn("re-proposed 2026-08-30-x design-landed", second.stdout)
        reproposed = self.plan("2026-08-30-x.plan.md")
        self.assertRegex(reproposed,
                         r"status=proposed .*cause=missing-design held=")
        self.assertTrue(any("design landed; plan re-proposed" in r
                            for r in self.rows()), self.rows())
        # and the following run accepts it normally
        third = self.run_accept()
        self.assertIn("accepted 2026-08-30-x", third.stdout)

    def test_still_held_is_quiet_and_deduped(self):
        self.write_plan("2026-08-30-x.plan.md", plan_md(
            [(" ", "do a thing", "make test")])
            + "\nPer docs/design/absent-spec.md.\n")
        self.run_accept()
        held_before = self.plan("2026-08-30-x.plan.md")
        subj = self.root / "research-subjects.txt"
        subj_before = subj.read_text()
        out = self.run_accept()  # still missing: no re-report, no re-append
        self.assertIn("still-held 2026-08-30-x", out.stdout)
        self.assertEqual(self.plan("2026-08-30-x.plan.md"), held_before)
        self.assertEqual(subj.read_text(), subj_before)


class PlanFeed(unittest.TestCase):
    def run_feed(self, plans):
        with tempfile.TemporaryDirectory() as td:
            home = Path(td) / "kernel"
            (home / "docs" / "project" / "plans").mkdir(parents=True)
            for name, text in plans.items():
                (home / "docs" / "project" / "plans" / name).write_text(text)
            out = Path(td) / "plans.json"
            env = {**os.environ, "HNGH_HOME": str(home),
                   "HNGH_PLANS_FEED_OUT": str(out), "DRY_RUN": "0"}
            r = subprocess.run([sys.executable, str(PLAN_FEED)], env=env,
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            return json.loads(out.read_text())["plans"]

    def test_steps_counted_beyond_2k(self):
        # the real 2026-08-30 failure: Steps section past the 2048-byte head
        filler = "Rationale line padding the plan past the old 2k head.\n" * 60
        text = ("<!-- plan: status=proposed risk=normal accepted=- -->\n"
                "# big plan\n\n" + filler + "## Steps\n\n"
                "- [ ] one: thing\n      Verification: make test\n"
                "- [ ] two: thing\n      Verification: make test\n"
                "- [x] three: thing\n      Verification: make test\n")
        feed = self.run_feed({"2026-08-30-big.plan.md": text})
        self.assertEqual(feed[0]["steps_total"], 3)
        self.assertEqual(feed[0]["steps_done"], 1)
        self.assertEqual(feed[0]["status"], "proposed")

    def test_accepted_timestamp_not_truncated(self):
        text = ("<!-- plan: status=executed risk=normal "
                "accepted=2026-08-28T17:35:00Z -->\n# p\n\n## Steps\n\n"
                "- [x] done: thing\n      Verification: make test\n")
        feed = self.run_feed({"2026-08-28-p.plan.md": text})
        self.assertEqual(feed[0]["accepted"], "2026-08-28T17:35:00Z")

    def test_held_status_and_cause_passthrough(self):
        text = ("<!-- plan: status=held risk=normal accepted=- "
                "cause=missing-design held=2026-09-06T03:00:00Z -->\n"
                "# p\n\nPer docs/design/absent-spec.md.\n\n## Steps\n\n"
                "- [ ] one: thing\n      Verification: make test\n")
        feed = self.run_feed({"2026-08-30-p.plan.md": text})
        self.assertEqual(feed[0]["status"], "held")
        self.assertEqual(feed[0]["accepted"], "-")


if __name__ == "__main__":
    unittest.main()
