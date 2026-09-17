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

import importlib.util
import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
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


class AppendResearchSubject(unittest.TestCase):
    """scripts/accept-plans.py append_research_subject (the python mirror
    of lib/causes.sh) must redact source-side, before id/slug derivation
    and before the append (2026-09-17: same leak shape as the shell
    appender -- a pathy question landed verbatim in the git-tracked TSV
    and its path tokens baked into the public id). One token family via
    lib/scrub.py imported directly; redaction fails closed to refusal."""

    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.td = Path(self._td.name)
        spec = importlib.util.spec_from_file_location(
            "accept_plans_test", ROOT / "scripts" / "accept-plans.py")
        self.mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.mod)
        self.orig_auto = self.mod.AUTOMATION
        self.mod.AUTOMATION = self.td  # state root only; scrub.py has
        # its own repo-tree resolution and never consults AUTOMATION

    def tearDown(self):
        self.mod.AUTOMATION = self.orig_auto
        self._td.cleanup()

    def rows(self):
        path = self.td / "research-subjects.txt"
        if not path.exists():
            return []
        return path.read_text(
            encoding="utf-8", errors="replace").splitlines()

    def test_pathy_question_redacted_in_text_and_id(self):
        self.assertTrue(self.mod.append_research_subject(
            "gate-exit-code",
            "Where exactly in /home/testuser/Projects/etc/hngh does the "
            "plan gate consume stderr?"))
        sid, text = self.rows()[0].split("\t", 1)
        self.assertNotIn("/home/testuser", text)
        self.assertIn("~/Projects/etc/hngh", text)
        self.assertNotIn("testuser", sid)
        self.assertTrue(sid.startswith("fail-"), sid)

    def test_slug_derived_from_redacted_question(self):
        self.assertTrue(self.mod.append_research_subject(
            "/home/testuser/Projects/which-gate",
            "Which gate consumes the make exit code?"))
        sid, text = self.rows()[0].split("\t", 1)
        self.assertNotIn("testuser", sid)
        self.assertNotIn("testuser", text)
        self.assertTrue(sid.startswith("fail-"), sid)

    def test_tmp_question_tilde_tmp_rendered(self):
        self.assertTrue(self.mod.append_research_subject(
            "scratch-sweep",
            "What lives in /tmp/scratch-dir after the sweep?"))
        sid, text = self.rows()[0].split("\t", 1)
        self.assertNotIn("/tmp/scratch-dir", text)
        self.assertIn("~tmp/scratch-dir", text)

    def test_repo_relative_question_unchanged(self):
        q = "Should automation/lib/redact.sh route through lib/scrub.py?"
        self.assertTrue(self.mod.append_research_subject("repo-rel", q))
        sid, text = self.rows()[0].split("\t", 1)
        self.assertEqual(text, q)

    def test_dedup_on_redacted_question_refuses(self):
        q = "Does the gate in /home/testuser/Projects/etc/hngh consume rc?"
        self.assertTrue(self.mod.append_research_subject("dup-check", q))
        self.assertEqual(len(self.rows()), 1)
        # the same raw question under a different slug dedups on the
        # REDACTED text (one token family, one dedup identity)
        self.assertFalse(self.mod.append_research_subject("other-slug", q))
        self.assertEqual(len(self.rows()), 1)

    def test_redaction_fail_closed_refuses_append(self):
        # guard broken (scrub module unavailable): refuse the append,
        # never write a leak
        orig = self.mod._SCRUB
        self.mod._SCRUB = None
        try:
            self.assertFalse(self.mod.append_research_subject(
                "broken-guard", "pathy /home/testuser/x question"))
            self.assertEqual(self.rows(), [])
        finally:
            self.mod._SCRUB = orig

    def test_dash_mangled_slug_never_bakes_username_into_id(self):
        # the exact audited leak shape: redact_home's token family
        # matches slash forms only, so a pre-mangled dash-form slug
        # passed whole and baked the username into the public id. The
        # appender must additionally cut dash-form pathy tokens at the
        # stem (class/word prefix preserved).
        self.assertTrue(self.mod.append_research_subject(
            "Where-exactly-in-home-bricker-Projects-e",
            "Does the plan-accept gate consume stderr?"))
        sid, text = self.rows()[0].split("\t", 1)
        self.assertNotIn("bricker", sid)
        self.assertNotIn("bricker", text)
        self.assertNotIn("home-", sid)
        day = datetime.now(timezone.utc).strftime("%Y%m%d")
        self.assertTrue(sid.startswith(
            "fail-%s-Where-exactly-in" % day), sid)

    def test_dash_mangled_whole_path_slug_refused(self):
        # fully path-derived slug: truncation yields nothing -> refuse,
        # nothing is written
        self.assertFalse(self.mod.append_research_subject(
            "home-bricker-Projects-etc-hngh",
            "Does the gate consume the exit code?"))
        self.assertEqual(self.rows(), [])

    def test_username_stem_seam_cuts_dash_form(self):
        # the deployment username is a stem through the same
        # HNGH_ROUTER_PATHY_STEMS seam router-tick reads
        old = os.environ.get("HNGH_ROUTER_PATHY_STEMS")
        os.environ["HNGH_ROUTER_PATHY_STEMS"] = "hermituser"
        try:
            self.assertTrue(self.mod.append_research_subject(
                "Where-in-hermituser-Dropbox-hngh-notes-x",
                "Do the notes say which gate runs first?"))
        finally:
            if old is None:
                os.environ.pop("HNGH_ROUTER_PATHY_STEMS", None)
            else:
                os.environ["HNGH_ROUTER_PATHY_STEMS"] = old
        sid, text = self.rows()[0].split("\t", 1)
        self.assertNotIn("hermituser", sid)
        self.assertNotIn("hermituser", text)
        self.assertTrue(sid.startswith("fail-"), sid)


if __name__ == "__main__":
    unittest.main()
