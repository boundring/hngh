#!/usr/bin/env python3
"""Plan-identity drift check, hermetic.

The bb67075 clobber: a session wrote "the next plan" into an existing
plan's filename, replacing an ACCEPTED plan's content with a fresh
status=proposed skeleton. Contract: a tracked plan file whose git HEAD
version carries a real accepted timestamp but whose working tree says
status=proposed accepted=- files an alert (identity
plan-identity-drift:<slug>) and is not processed; consistent plans
pass untouched. The check consults git only for tracked files; an
absent repo skips silently (behavior-preserving).
"""

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ACCEPT = ROOT / "scripts" / "accept-plans.py"

ACCEPTED = """<!-- plan: status=accepted risk=normal accepted=2026-09-09T15:01:13Z -->
# 2026-09-09 - stall recovery, operator surfaces, lifecycle accommodation

## Steps

- [ ] step one: do the recovery
      Verification: make test
"""

CLOBBERED = """<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-09 - stall-recovery-and-operator-surfaces

## Steps

- [ ] a brand new unrelated plan body
      Verification: make test
"""


class PlanIdentity(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name)
        self.kernel = self.root / "kernel"
        self.plans = self.kernel / "docs" / "project" / "plans"
        self.plans.mkdir(parents=True)
        self.auto = self.root / "auto"
        self.auto.mkdir()
        self.gate = self.root / "gate.sh"
        self.gate.write_text("#!/usr/bin/env bash\nexit 0\n")
        self.gate.chmod(0o755)
        self.queue = self.root / "queue.sh"
        self.queue.write_text(
            "#!/usr/bin/env bash\nprintf '%s\\n' \"$*\" >> '"
            + str(self.root / "queue.log") + "'\n")
        self.queue.chmod(0o755)
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
        }

    def tearDown(self):
        self._td.cleanup()

    def run_accept(self):
        return subprocess.run([sys.executable, str(ACCEPT)],
                              env=self.env, capture_output=True, text=True)

    def git_commit(self):
        for args in (("init", "-q"), ("add", "docs/project/plans"),
                     ("commit", "-qm", "fixture")):
            r = subprocess.run(["git", "-C", str(self.kernel),
                                "-c", "user.email=t@t", "-c", "user.name=t",
                                *args], capture_output=True, text=True)
            if r.returncode:
                return r
        return r

    def rows(self):
        log = self.root / "queue.log"
        return log.read_text().splitlines() if log.exists() else []

    def test_tracked_accepted_plan_reverting_to_proposed_alerts(self):
        f = self.plans / "2026-09-09-stall-recovery.plan.md"
        f.write_text(ACCEPTED, encoding="utf-8")
        self.git_commit()
        f.write_text(CLOBBERED, encoding="utf-8")
        out = self.run_accept()
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertEqual(f.read_text(encoding="utf-8"), CLOBBERED)  # untouched
        self.assertIn("blocked 2026-09-09-stall-recovery plan-identity-drift",
                      out.stdout)
        self.assertTrue(any("plan-identity-drift:2026-09-09-stall-recovery"
                            in r for r in self.rows()), self.rows())
        self.assertIn("plan-identity-drift",
                      (self.root / "acceptance.log").read_text())

    def test_consistent_plans_pass_untouched(self):
        proposed = ACCEPTED.replace(
            "status=accepted risk=normal accepted=2026-09-09T15:01:13Z",
            "status=proposed risk=normal accepted=-")
        f = self.plans / "2026-09-10-new-thing.plan.md"
        f.write_text(proposed, encoding="utf-8")
        out = self.run_accept()
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("accepted 2026-09-10-new-thing", out.stdout)
        self.assertFalse(any("identity-drift" in r for r in self.rows()),
                         self.rows())
        g = self.plans / "2026-09-10-other.plan.md"
        g.write_text(ACCEPTED, encoding="utf-8")
        self.git_commit()
        out = self.run_accept()
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertFalse(any("identity-drift" in r for r in self.rows()),
                         self.rows())
        self.assertEqual(g.read_text(encoding="utf-8"), ACCEPTED)


if __name__ == "__main__":
    unittest.main(verbosity=2)
