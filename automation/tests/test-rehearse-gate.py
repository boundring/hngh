#!/usr/bin/env python3
"""rehearse-gate.sh + accept-plans isolated-gate opt-in, hermetic.

Rehearsal-lane plan step 2 (2026-09-09): gate pre-validation runs on a
git archive HEAD copy instead of contending with parallel delegated
sessions. Proved here on sandbox trees:
  a) a sandbox archive runs the stub gate (green gate -> rc 0)
  b) dirty working-tree diffs stay out of the archived copy
  c) named candidate files overlay the working-tree content onto the
     archived copy
  d) a red gate propagates its rc and prints the last failing check
  e) refuse conditions (non-git repo, escaping candidate) exit 2
  f) accept-plans ACCEPT_ISOLATED_GATE is off by default (direct gate
     run preserved) and opt-in routes both gates through the rehearsal
No real repository, no real make test, no network.
"""

import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REHEARSE = ROOT / "scripts" / "rehearse-gate.sh"
ACCEPT = ROOT / "scripts" / "accept-plans.py"

TS = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z")


def run(argv, **kw):
    return subprocess.run([str(a) for a in argv], capture_output=True,
                          text=True, **kw)


def git(repo, *args):
    env = dict(os.environ)
    # containment: never inherit repo selection from the caller's shell
    # (2026-09-17 kernel-contamination lesson)
    for hostile in ("GIT_DIR", "GIT_WORK_TREE"):
        env.pop(hostile, None)
    r = subprocess.run(["git", "-C", repo] + list(args),
                       capture_output=True, text=True, env=env)
    if r.returncode != 0:
        raise AssertionError("git %s failed: %s" % (args[0], r.stderr))
    return r


def plan_md():
    return ("<!-- plan: status=proposed risk=normal accepted=- -->\n"
            "\n# fixture plan\n\n## Steps\n\n"
            "- [ ] step 1: do the thing\n"
            "      Verification: python3 tests/fixture-verify.py\n\n")


class RehearseGate(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name)
        self.repo = self.root / "repo"
        self.repo.mkdir(parents=True)
        # The stub gate appends to an ABSOLUTE path outside the repo:
        # the archive copy lives in a temp dir the script's EXIT trap
        # destroys, so anything the gate writes there dies with it.
        self.gatelog = self.root / "gatelog"
        (self.repo / "Makefile").write_text(
            "test:\n\techo committed-version >> %s\n" % self.gatelog)
        git(self.repo, "init", "-q")
        git(self.repo, "add", "-A")
        git(self.repo, "-c", "user.email=t@t", "-c", "user.name=t",
            "commit", "-qm", "init")
        self.rlog = self.root / "rehearse.log"
        self.env = {**os.environ, "REHEARSE_LOG": str(self.rlog)}


    def tearDown(self):
        self._td.cleanup()

    def rehearse(self, *args, gate=None):
        argv = [REHEARSE]
        if gate is not None:
            argv += ["--gate", gate]
        argv += ["--", self.repo, *args]
        return run(argv, env=self.env)

    def gatelog_lines(self):
        return (self.gatelog.read_text().splitlines()
                if self.gatelog.exists() else [])

    def test_green_gate_runs_in_archive(self):
        r = self.rehearse()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.gatelog_lines(), ["committed-version"])
        rows = self.rlog.read_text().splitlines()
        self.assertEqual(len(rows), 1)
        self.assertIn("rc=0", rows[0])
        self.assertIn("repo=" + str(self.repo), rows[0])
        self.assertIn("gate=make test", rows[0])
        self.assertRegex(rows[0], TS)

    def test_dirty_working_tree_stays_out_of_archive(self):
        (self.repo / "Makefile").write_text(
            "test:\n\techo dirty-version >> %s\n" % (self.root / "gatelog"))
        r = self.rehearse()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.gatelog_lines(), ["committed-version"])

    def test_named_candidate_overlays_working_tree_content(self):
        (self.repo / "Makefile").write_text(
            "test:\n\techo candidate-version >> %s\n" % (self.root / "gatelog"))
        r = self.rehearse("Makefile")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.gatelog_lines(), ["candidate-version"])

    def test_red_gate_propagates_rc_and_last_failing_check(self):
        failgate = self.root / "failgate.sh"
        failgate.write_text("#!/bin/sh\necho boom-middle-check\necho boom\nexit 1\n")
        failgate.chmod(0o755)
        r = self.rehearse(gate=str(failgate))
        self.assertEqual(r.returncode, 1)
        self.assertIn("rc=1", r.stderr)
        self.assertIn("boom", r.stderr)

    def test_refuses_non_git_directory(self):
        r = run([REHEARSE, "--gate", "true", "--", self.root], env=self.env)
        self.assertEqual(r.returncode, 2)
        self.assertIn("git", r.stderr.lower())


    def test_refuses_escaping_candidate_path(self):
        for bad in ("/etc/passwd", "../outside", "sub/../../x"):
            r = self.rehearse(bad)
            self.assertEqual(r.returncode, 2, bad)
            self.assertIn("refus", r.stderr.lower(), bad)

    def test_refuses_missing_candidate_file(self):
        r = self.rehearse("no-such-file.md")
        self.assertEqual(r.returncode, 2)
        self.assertIn("no-such-file.md", r.stderr)


class IsolatedGateOptIn(unittest.TestCase):
    """accept-plans wiring: off by default; opt-in rehearses both gates."""

    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name)
        self.kernel = self.root / "kernel"
        (self.kernel / "docs" / "project" / "plans").mkdir(parents=True)
        git(self.kernel, "init", "-q")
        (self.kernel / "README.md").write_text("sandbox kernel\n")
        git(self.kernel, "add", "-A")
        git(self.kernel, "-c", "user.email=t@t", "-c", "user.name=t",
            "commit", "-qm", "init")
        self.auto = self.root / "auto"
        self.auto.mkdir()
        # the rehearsal archives the automation repo too: give the
        # fixture a commit so `git archive HEAD` has something to unpack
        (self.auto / "README.md").write_text("sandbox automation\n")
        git(self.auto, "init", "-q")
        git(self.auto, "add", "-A")
        git(self.auto, "-c", "user.email=t@t", "-c", "user.name=t",
            "commit", "-qm", "init")
        self.gate = self.root / "gate.sh"
        self.gate.write_text(
            "#!/usr/bin/env bash\n"
            "printf '%s\\n' \"$1 $PWD\" >> " + str(self.root / "gate.log") + "\n"
            "exit \"$1\"\n")
        self.gate.chmod(0o755)
        self.queue = self.root / "queue.sh"
        self.queue.write_text(
            "#!/usr/bin/env bash\n"
            "printf '%s\\n' \"$*\" >> " + str(self.root / "queue.log") + "\n")
        self.queue.chmod(0o755)
        self.plan = self.kernel / "docs" / "project" / "plans" / "fix.plan.md"
        self.plan.write_text(plan_md(), encoding="utf-8")
        self.rlog = self.root / "rehearse.log"
        self.env = {
            **os.environ,
            "DRY_RUN": "0",
            "HNGH_HOME": str(self.kernel),
            "HNGH_AUTOMATION_ROOT": str(self.auto),
            "ACCEPT_KERNEL_GATE": "%s 0" % self.gate,
            "ACCEPT_AUTOMATION_GATE": "%s 0" % self.gate,
            "HNGH_REPORT_QUEUE": str(self.queue),
            "HNGH_REPORT_ROOT": str(self.kernel),
            "ACCEPT_LOG": str(self.root / "acceptance.log"),
            "HNGH_RESEARCH_SUBJECTS": str(self.root / "research-subjects.txt"),
            "REHEARSE_LOG": str(self.rlog),
        }  # ACCEPT_ISOLATED_GATE deliberately unset: off by default

    def tearDown(self):
        self._td.cleanup()

    def accept(self, **extra):
        return run([sys.executable, ACCEPT],
                   env={**self.env, **extra})

    def queue_rows(self):
        q = self.root / "queue.log"
        return q.read_text().splitlines() if q.exists() else []

    def test_off_by_default_preserves_direct_gate_run(self):
        r = self.accept()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(self.rlog.exists(),
                         "rehearsal ran without the opt-in")
        gatelog = self.root / "gate.log"
        self.assertTrue(gatelog.exists())
        lines = gatelog.read_text().splitlines()
        self.assertEqual(len(lines), 2)  # kernel + automation, direct rc=0
        rows = self.queue_rows()
        self.assertTrue(any("plan fix.plan.md auto-accepted" in row
                            or "auto-accepted" in row for row in rows))

    def test_opt_in_rehearses_both_gates_and_accepts_green(self):
        r = self.accept(ACCEPT_ISOLATED_GATE="1")
        self.assertEqual(r.returncode, 0, r.stderr)
        rows = self.rlog.read_text().splitlines()
        self.assertEqual(len(rows), 2, rows)
        self.assertTrue(all("rc=0" in row for row in rows))
        self.assertTrue(any("repo=" + str(self.kernel) in row for row in rows))
        self.assertTrue(any("repo=" + str(self.auto) in row for row in rows))
        self.assertTrue(any("auto-accepted" in row for row in self.queue_rows()))

    def test_opt_in_red_kernel_rehearsal_blocks_acceptance(self):
        r = self.accept(ACCEPT_ISOLATED_GATE="1",
                        ACCEPT_KERNEL_GATE="%s 1" % self.gate)
        self.assertEqual(r.returncode, 0, r.stderr)
        rows = self.rlog.read_text().splitlines()
        self.assertEqual(len(rows), 1)  # kernel rehearsal ran red
        self.assertIn("rc=1", rows[0])
        self.assertFalse(any("auto-accepted" in row
                             for row in self.queue_rows()))
        self.assertTrue(any("kernel" in row and "FAILED" in row
                            for row in self.queue_rows()))


if __name__ == "__main__":
    unittest.main()
