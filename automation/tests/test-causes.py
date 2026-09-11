#!/usr/bin/env python3
"""classify_cause + lesson_for_cause, hermetic (fixture tails only).

Regression base: the first supervised opencode session (2026-09-11,
record docs/records/2026-09-11-opencode-configuration.md s4) ended
cleanly (rc=0) but its log tail innocuously mentioned "check the
budget/breadcrumbs" — the bare-word budget rule classified bad-execution,
appending a false lesson line and incrementing the demote counter. A
bare vocabulary word must not classify; the budget/exhaustion class
requires failure-context phrases on the same line (still deterministic
keyword matching, no model call — causes.sh's design constraint).
"""

import subprocess
import tempfile
import unittest
from pathlib import Path

AUTO = Path(__file__).resolve().parent.parent

# arg1 = tail file, arg2 = a cause class for lesson_for_cause
DRIVER = """#!/usr/bin/env bash
set -u
. {auto}/lib/causes.sh
printf 'class=%s\\n' "$(classify_cause "$1")"
printf 'lesson=%s\\n' "$(lesson_for_cause "$2")"
"""


class ClassifyCause(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.td = Path(self._td.name)
        self.driver = self.td / "driver.sh"
        self.driver.write_text(DRIVER.format(auto=AUTO))
        self.driver.chmod(0o755)

    def tearDown(self):
        self._td.cleanup()

    def classify(self, tail, lesson_class="bad-execution"):
        log = self.td / "tail.log"
        log.write_text(tail)
        r = subprocess.run(["bash", str(self.driver), str(log), lesson_class],
                           capture_output=True, text=True, timeout=30)
        self.assertEqual(r.returncode, 0, r.stderr)
        lines = dict(l.split("=", 1) for l in r.stdout.strip().splitlines())
        return lines["class"], lines["lesson"]

    def test_success_context_budget_mention_is_unknown(self):
        # the exact first-session tail line that misfired
        tail = ("One prior opencode session log exists (23:32 UTC Sep 10 — "
                "before the loop landed 2026-09-11). Let me confirm the "
                "timeline via git, and check the budget/breadcrumbs.")
        self.assertEqual(self.classify(tail)[0], "unknown")

    def test_loadout_budget_passing_mention_is_unknown(self):
        self.assertEqual(self.classify("context pack cites the "
                                       "loadout-budget 2000 row")[0],
                         "unknown")

    def test_real_cost_failure_is_bad_execution(self):
        self.assertEqual(self.classify("error: cost limit exceeded while "
                                       "integrating")[0], "bad-execution")

    def test_real_budget_exceeded_is_bad_execution(self):
        self.assertEqual(self.classify("session aborted: budget exceeded "
                                       "during step 3")[0], "bad-execution")

    def test_cap_reached_is_bad_execution(self):
        self.assertEqual(self.classify("5h cap reached on the pacer")[0],
                         "bad-execution")

    def test_timeout_still_classifies(self):
        self.assertEqual(self.classify("error: timeout exceeded while "
                                       "integrating")[0], "bad-execution")

    def test_lesson_for_cause_maps_sensibly(self):
        _, lesson = self.classify("x", "bad-execution")
        self.assertIn("step was too big", lesson)
        _, lesson = self.classify("x", "unknown")
        self.assertIn("no known failure class", lesson)


if __name__ == "__main__":
    unittest.main()
