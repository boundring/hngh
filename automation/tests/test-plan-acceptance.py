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

    # --- gate evaluation isolation (plan 2026-09-09 step 5) --------------

    def test_concurrent_gate_evaluations_serialize(self):
        # two accepts racing evaluate at most one gate at a time: the
        # per-pid start/end pairs in the gate log are contiguous (--
        # never start,pid-a / start,pid-b / end,pid-a interleaving).
        self.write_plan("2026-08-30-x.plan.md",
                        plan_md([(" ", "do a thing", "make test")]))
        self.gate.write_text(
            "#!/usr/bin/env bash\n"
            "printf '%s\\n' \"start $$\" >> " + str(self.root / "gate.log") + "\n"
            "sleep 0.5\n"
            "printf '%s\\n' \"end $$\" >> " + str(self.root / "gate.log") + "\n"
            "exit 0\n")
        self.gate.chmod(0o755)
        procs = [subprocess.Popen([sys.executable, str(ACCEPT)], env=self.env,
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                  text=True) for _ in range(2)]
        for p in procs:
            p.wait()
        events = self.gate_log()
        starts = [i for i, ev in enumerate(events) if ev.startswith("start ")]
        for i in starts[:-1]:
            self.assertEqual(events[i + 1], events[i].replace("start ", "end "),
                             "gates interleaved: %s" % events)

    def test_gate_lock_busy_blocks_loudly(self):
        # a concurrent gate evaluation holds the lock: this run must NOT
        # pile on (the flap shape) but must also not block silently -
        # alert row, noted lines, plans untouched, gates not consulted.
        self.write_plan("2026-08-30-x.plan.md",
                        plan_md([(" ", "do a thing", "make test")]))
        import fcntl
        lock = self.root / "gate.lock"
        self.env["ACCEPT_GATE_LOCK"] = str(lock)
        fd = open(lock, "w")
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        out = self.run_accept()
        self.assertIn("gate-lock-busy", out.stdout)
        self.assertEqual(self.gate_log(), [])
        self.assertNotIn("status=accepted", self.plan("2026-08-30-x.plan.md"))
        self.assertTrue(any("alert" in r and "gate lock" in r
                            for r in self.rows()), self.rows())
        fcntl.flock(fd, fcntl.LOCK_UN)
        fd.close()

    def test_gate_lock_free_runs_normally(self):
        # the seam default: no env, default lock path, gates run and the
        # plan accepts -- the lock must never wedge the normal path.
        self.write_plan("2026-08-30-x.plan.md",
                        plan_md([(" ", "do a thing", "make test")]))
        out = self.run_accept()
        self.assertIn("accepted 2026-08-30-x", out.stdout)
        self.assertEqual(len(self.gate_log()), 2)


class PlanFeed(unittest.TestCase):
    def run_feed(self, plans, queue_md=None, ceremony_log=None):
        with tempfile.TemporaryDirectory() as td:
            home = Path(td) / "kernel"
            (home / "docs" / "project" / "plans").mkdir(parents=True)
            for name, text in plans.items():
                (home / "docs" / "project" / "plans" / name).write_text(text)
            if queue_md is not None:
                (home / "docs" / "project" / "queue.md").write_text(queue_md)
            out = Path(td) / "plans.json"
            env = {**os.environ, "HNGH_HOME": str(home),
                   "HNGH_PLANS_FEED_OUT": str(out), "DRY_RUN": "0",
                   "HNGH_CEREMONY_LOG": ceremony_log or ""}
            r = subprocess.run([sys.executable, str(PLAN_FEED)], env=env,
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            return json.loads(out.read_text())

    def test_steps_counted_beyond_2k(self):
        # the real 2026-08-30 failure: Steps section past the 2048-byte head
        filler = "Rationale line padding the plan past the old 2k head.\n" * 60
        text = ("<!-- plan: status=proposed risk=normal accepted=- -->\n"
                "# big plan\n\n" + filler + "## Steps\n\n"
                "- [ ] one: thing\n      Verification: make test\n"
                "- [ ] two: thing\n      Verification: make test\n"
                "- [x] three: thing\n      Verification: make test\n")
        feed = self.run_feed({"2026-08-30-big.plan.md": text})
        self.assertEqual(feed["plans"][0]["steps_total"], 3)
        self.assertEqual(feed["plans"][0]["steps_done"], 1)
        self.assertEqual(feed["plans"][0]["status"], "proposed")

    def test_accepted_timestamp_not_truncated(self):
        text = ("<!-- plan: status=executed risk=normal "
                "accepted=2026-08-28T17:35:00Z -->\n# p\n\n## Steps\n\n"
                "- [x] done: thing\n      Verification: make test\n")
        feed = self.run_feed({"2026-08-28-p.plan.md": text})
        self.assertEqual(feed["plans"][0]["accepted"], "2026-08-28T17:35:00Z")

    def test_held_status_and_cause_passthrough(self):
        text = ("<!-- plan: status=held risk=normal accepted=- "
                "cause=missing-design held=2026-09-06T03:00:00Z -->\n"
                "# p\n\nPer docs/design/absent-spec.md.\n\n## Steps\n\n"
                "- [ ] one: thing\n      Verification: make test\n")
        feed = self.run_feed({"2026-08-30-p.plan.md": text})
        self.assertEqual(feed["plans"][0]["status"], "held")
        self.assertEqual(feed["plans"][0]["accepted"], "-")

    def test_queue_next_parsed_from_fixture(self):
        feed = self.run_feed(
            {"2026-08-30-p.plan.md": plan_md([("x", "one", "make test")])},
            queue_md="## Next\n\n"
                     "- **wake-mutation-lane** — rotate next (pins wake).\n\n"
                     "## Scheduling\n\n- other: thing\n")
        self.assertEqual(feed["queue_next"], "wake-mutation-lane")

    def test_queue_next_fail_closed_without_queue(self):
        feed = self.run_feed(
            {"2026-08-30-p.plan.md": plan_md([("x", "one", "make test")])})
        self.assertIsNone(feed["queue_next"])

    def test_last_ceremony_parsed_from_git_log_seam(self):
        log = ("abc123|%cs|feat: unrelated\n"
               "def456|2026-09-10|hngh: candidate sealed rotation r1\n")
        feed = self.run_feed(
            {"2026-08-30-p.plan.md": plan_md([("x", "one", "make test")])},
            ceremony_log=log)
        self.assertEqual(feed["last_ceremony_commit"], {
            "hash": "def456", "date": "2026-09-10",
            "subject": "hngh: candidate sealed rotation r1"})

    def test_last_ceremony_none_without_candidate(self):
        feed = self.run_feed(
            {"2026-08-30-p.plan.md": plan_md([("x", "one", "make test")])},
            ceremony_log="abc123|2026-09-10|feat: not a ceremony\n")
        self.assertIsNone(feed["last_ceremony_commit"])


class PlansViewContract(unittest.TestCase):
    """Textual contract for the static Plans tab (plan step 10): the page
    must render the two new feed fields plus the plans rows, and be
    mounted in the tab system — string-level checks are the honest
    runnable regression for a static page (test-readout-writers style)."""

    # dashboard/ is machine data, quarantined out of git
    # (automation/.gitignore) — a fresh clone has no surface to check
    def _skip_absent(self):
        if not (ROOT / "dashboard" / "index.html").is_file():
            self.skipTest("dashboard/ not present (quarantined machine data)")

    def test_view_renders_feed_fields(self):
        self._skip_absent()
        view = (ROOT / "dashboard" / "plans-view.js").read_text()
        for field in ("queue_next", "last_ceremony_commit", "plans"):
            self.assertIn(field, view)

    def test_view_mounted_in_page(self):
        self._skip_absent()
        page = (ROOT / "dashboard" / "index.html").read_text()
        app = (ROOT / "dashboard" / "app.js").read_text()
        self.assertIn('data-tab="plans"', page)
        self.assertIn('id="plans-root"', page)
        self.assertIn('src="plans-view.js"', page)
        self.assertIn("'plans-root':    ['plans',    'PlansView']", app)


if __name__ == "__main__":
    unittest.main()
