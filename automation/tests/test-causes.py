#!/usr/bin/env python3
"""classify_cause + lesson_for_cause, hermetic (fixture tails only).

Regression base: the first supervised opencode session (2026-09-11,
record docs/records/2026-09-11-opencode-configuration.md s4) ended
cleanly (rc=0) but its log tail innocuously mentioned "check the
budget/breadcrumbs" — the bare-word budget rule classified bad-execution,
appending a false lesson line and incrementing the demote counter. A
bare vocabulary word must not classify. A second success-shaped tail
innocuously mentioned "404" in prose and classified missing-knowledge
the same day. Both are fixed by two-stage classification: keep only
failure-shaped lines, then run the class table on those (still
deterministic keyword matching, no model call -- causes.sh's design
constraint).
"""

import subprocess
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

AUTO = Path(__file__).resolve().parent.parent

# arg1 = tail file, arg2 = a cause class for lesson_for_cause, arg3 = rc
DRIVER = """#!/usr/bin/env bash
set -u
. {auto}/lib/causes.sh
printf 'class=%s\\n' "$(classify_cause "$1" "$3")"
printf 'lesson=%s\\n' "$(lesson_for_cause "$2")"
"""

# append_research_subject driver: AUTOMATION_ROOT points at a lib-less
# SANDBOX (state only -- the exact mimic-drill 18-mimic-drill.sh leg (a)
# configuration), so causes.sh must source the redaction loader from its
# own tree and the loader must resolve scrub.py from its own tree too.
# PRE runs between sourcing and the call (fail-closed simulation).
DRIVER_APPEND = """#!/usr/bin/env bash
set -u
export AUTOMATION_ROOT={td}
. {auto}/lib/causes.sh
{pre}append_research_subject "$1" "$2"
printf 'rc=%s\\n' "$?"
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

    def classify(self, tail, lesson_class="bad-execution", rc=""):
        log = self.td / "tail.log"
        log.write_text(tail)
        r = subprocess.run(["bash", str(self.driver), str(log), lesson_class,
                            rc],
                           capture_output=True, text=True, timeout=30)
        self.assertEqual(r.returncode, 0, r.stderr)
        lines = dict(l.split("=", 1) for l in r.stdout.strip().splitlines())
        return lines["class"], lines["lesson"]

    def test_success_context_budget_mention_is_unknown(self):
        # the exact first-session tail line that misfired
        tail = ("One prior opencode session log exists (23:32 UTC Sep 10 — "
                "before the loop landed 2026-09-11). Let me confirm the "
                "timeline via git, and check the budget/breadcrumbs.")
        self.assertEqual(self.classify(tail)[0], "unclassified")

    def test_loadout_budget_passing_mention_is_unknown(self):
        self.assertEqual(self.classify("context pack cites the "
                                       "loadout-budget 2000 row")[0],
                         "unclassified")

    def test_success_prose_404_mention_is_unknown(self):
        # the exact 13:45:25Z session-2 misfire: rc=0 success whose log
        # prose innocuously cites 404s (research docs) -> stays unclassified
        tail = ("Checked the research docs (they mention 404 handling) and "
                "the draft landed cleanly. Session complete.")
        self.assertEqual(self.classify(tail)[0], "unclassified")

    def test_failure_line_with_404_is_missing_knowledge(self):
        self.assertEqual(self.classify("error: 404 not found while fetching "
                                       "verb")[0], "missing-knowledge")

    def test_incidental_404_beside_failure_stays_unclassified(self):
        # failure-shaped lines exist but none carries a class keyword
        tail = ("the build failed on a flaky step\n"
                "the research docs mention 404s in passing")
        self.assertEqual(self.classify(tail)[0], "unclassified")

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

    def test_rc124_timeout_is_bad_execution_even_with_clean_tail(self):
        # the worker-transport-wiring stall (2026-09-11): a timeout kill
        # (rc=124) left a clean "Working..." tail, classified unclassified,
        # and the respawn guard refused it as non-transient. A timeout
        # IS a transient death by definition (steer-vs-die doctrine).
        self.assertEqual(self.classify("Working...\n", "bad-execution",
                                       "124")[0], "bad-execution")

    def test_rc124_does_not_mask_a_more_specific_text_class(self):
        self.assertEqual(self.classify("error: permission denied\n",
                                       "missing-authority", "124")[0],
                         "missing-authority")

    def test_rc0_clean_tail_stays_unknown(self):
        self.assertEqual(self.classify("Working...\n", "unknown", "0")[0],
                         "unclassified")

    def test_lesson_for_cause_maps_sensibly(self):
        _, lesson = self.classify("x", "bad-execution")
        self.assertIn("step was too big", lesson)
        _, lesson = self.classify("x", "unclassified")
        self.assertIn("no known failure class", lesson)


class AppendResearchSubject(unittest.TestCase):
    """append_research_subject redacts source-side, before id/slug
    derivation and before the append (2026-09-17: the ingest fix closed
    only the beat seams; this appender had the same leak shape -- a
    pathy question appended verbatim and baked path tokens into the
    git-tracked public id). One token family via lib/scrub.py through
    lib/redact.sh: /home/<user> -> ~, /tmp -> ~tmp, and the id slug is
    derived from the REDACTED question. Redaction fails closed: a
    broken guard yields empty output and the append is refused, never
    a leak."""

    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.td = Path(self._td.name)
        self.subjects = self.td / "research-subjects.txt"
        self.subjects.touch()
        self.driver = self.td / "driver_append.sh"
        self.driver.write_text(DRIVER_APPEND.format(
            auto=AUTO, td=self.td, pre=""))
        self.driver.chmod(0o755)

    def tearDown(self):
        self._td.cleanup()

    def append(self, slug, question, pre=""):
        """AUTOMATION_ROOT -> the sandbox (state only, no lib/): the
        exact 18-mimic-drill.sh leg (a) configuration. `pre` runs after
        sourcing causes.sh (fail-closed simulation)."""
        if pre:
            self.driver.write_text(DRIVER_APPEND.format(
                auto=AUTO, td=self.td, pre=pre))
        return subprocess.run(
            ["bash", str(self.driver), slug, question],
            capture_output=True, text=True, timeout=30)

    def rows(self):
        out = []
        if self.subjects.exists():
            out = self.subjects.read_text(
                encoding="utf-8", errors="replace").splitlines()
        return out

    def today(self):
        return datetime.now(timezone.utc).strftime("%Y%m%d")

    def test_pathy_question_redacted_in_text_and_id(self):
        r = self.append(
            "gate-exit-code",
            "Where exactly in /home/testuser/Projects/etc/hngh does the "
            "plan gate consume stderr?")
        self.assertEqual(r.returncode, 0, r.stderr)
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        sid, text = rows[0].split("\t", 1)
        self.assertNotIn("/home/testuser", text)
        self.assertIn("~/Projects/etc/hngh", text)
        self.assertNotIn("testuser", sid)
        # id slug derived from the redacted question
        self.assertEqual(sid, "fail-%s-gate-exit-code" % self.today())

    def test_slug_derived_from_redacted_question(self):
        # slug itself pathy: it must be redacted before slug mangling.
        # The id derives from the REDACTED slug: no /home or user token
        # survives (interior fragments like Projects- are fine).
        r = self.append(
            "/home/testuser/Projects/which-gate",
            "Which gate consumes the make exit code?")
        self.assertEqual(r.returncode, 0, r.stderr)
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        sid, text = rows[0].split("\t", 1)
        self.assertNotIn("testuser", sid)
        self.assertNotIn("testuser", text)
        self.assertIn("which-gate", sid)
        self.assertTrue(sid.startswith("fail-%s-" % self.today()), sid)

    def test_tmp_question_tilde_tmp_rendered(self):
        r = self.append(
            "scratch-sweep", "What lives in /tmp/scratch-dir after the sweep?")
        self.assertEqual(r.returncode, 0, r.stderr)
        sid, text = self.rows()[0].split("\t", 1)
        self.assertNotIn("/tmp/scratch-dir", text)
        self.assertIn("~tmp/scratch-dir", text)

    def test_repo_relative_question_unchanged(self):
        # the guard must not mangle in-repo references
        q = "Should automation/lib/redact.sh route through lib/scrub.py?"
        r = self.append("repo-rel", q)
        self.assertEqual(r.returncode, 0, r.stderr)
        sid, text = self.rows()[0].split("\t", 1)
        self.assertEqual(text, q)
        self.assertEqual(sid, "fail-%s-repo-rel" % self.today())

    def test_dedup_still_refuses_same_id(self):
        q1 = "Does the gate in /home/testuser/Projects/etc/hngh consume rc?"
        self.assertEqual(self.append("dup-check", q1).returncode, 0)
        self.assertEqual(len(self.rows()), 1)
        # same slug again: id-prefix dedup must still refuse
        r = self.append("dup-check", "a different question entirely")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(len(self.rows()), 1)
        self.assertIn("Does the gate in", self.rows()[0])

    def test_redaction_fail_closed_refuses_append(self):
        # redact_home is a command substitution: a broken guard (here:
        # stubbed to emit nothing, the exact scrub.sh fail-closed
        # behavior) yields empty output, so the empty-question guard
        # refuses the append. A leak is impossible; a silent empty row
        # is impossible too.
        r = self.append("fail-closed", "any question at all",
                        pre="redact_home() { :; }\n")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.rows(), [])
        self.assertIn("rc=1", r.stdout)

    def test_broken_scrub_fail_closed_refuses_append(self):
        # scrub.py unreachable (SCRUB_PY severed -- loader fails closed
        # to empty output): the append is refused, nothing is written.
        missing = self.td / "missing" / "scrub.py"
        r = self.append("broken-guard", "pathy /home/testuser/x question",
                        pre="export SCRUB_PY=%s\n" % missing)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.rows(), [])
        self.assertIn("rc=1", r.stdout)

    def test_dash_mangled_slug_never_bakes_username_into_id(self):
        # the exact audited leak shape (fail-20260914-Where-exactly-in-
        # home-bricker-Projects-e): redact_home's token family matches
        # slash forms only, so a pre-mangled dash-form slug passed whole.
        # The appender must additionally cut dash-form pathy tokens at
        # the stem (class/word prefix preserved), never emit a
        # username-bearing id.
        r = self.append("Where-exactly-in-home-bricker-Projects-e",
                        "Does the plan-accept gate consume stderr?")
        self.assertEqual(r.returncode, 0, r.stderr)
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        sid, text = rows[0].split("\t", 1)
        self.assertNotIn("bricker", sid)
        self.assertNotIn("bricker", text)
        self.assertNotIn("home-", sid)
        self.assertTrue(sid.startswith("fail-%s-Where-exactly-in" %
                                       self.today()), sid)

    def test_dash_mangled_whole_path_slug_refused(self):
        # fully path-derived slug: the truncation yields nothing, the
        # appender refuses (fail closed), nothing is written.
        r = self.append("home-bricker-Projects-etc-hngh",
                        "Does the gate consume the exit code?")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.rows(), [])
        self.assertIn("rc=1", r.stdout)

    def test_username_stem_seam_cuts_dash_form(self):
        # the deployment username is a stem through the same
        # HNGH_ROUTER_PATHY_STEMS seam router-tick reads; a dash-form
        # slug carrying it is cut before the username fragment.
        self.driver.write_text(DRIVER_APPEND.format(
            auto=AUTO, td=self.td,
            pre="export HNGH_ROUTER_PATHY_STEMS=hermituser\n"))
        r = self.append("Where-in-hermituser-Dropbox-hngh-notes-x",
                        "Do the notes say which gate runs first?")
        self.assertEqual(r.returncode, 0, r.stderr)
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        sid, text = rows[0].split("\t", 1)
        self.assertNotIn("hermituser", sid)
        self.assertNotIn("hermituser", text)
        # shell slug mangling strips the trailing dash
        self.assertTrue(sid.startswith(
            "fail-%s-Where-in" % self.today()), sid)


if __name__ == "__main__":
    unittest.main()
