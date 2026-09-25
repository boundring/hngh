#!/usr/bin/env python3
"""Alert-lifecycle contract, hermetic (alert-lifecycle fold):

- CANDIDATE EXPIRY: a routed candidate unaccepted after
  HNGH_ROUTER_TTL_HOURS (default 24h; cadence-params row
  routed-candidate-ttl-hours) is marked status=expired (header
  rewrite, never deletion) and files exactly one
  router:routed-expired:<candidate-id> row (unlimited-lookback
  identity, so repeats never add rows).
- ESCALATION ON RECURRENCE: a re-fire whose newest same-identity
  candidate is expired escalates immediately (identity
  router:escalated:<orig-id>, with the recurrence count and the
  oldest occurrence ts), skipping remaining suppressions, and the
  alert routes fresh.
- Below the escalation threshold a live-duplicate re-fire stays a
  plain dedup suppression.
"""

import json
import os
import re
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TICK = ROOT / "scripts" / "router-tick.py"
sys.path.insert(0, str(ROOT / "lib"))
import report_queue  # the shared row shim (lib/report_queue.py)


def routed_candidate(slug_date="2026-09-15", ident="gate-make-test",
                     status="proposed", occurrences=0):
    lines = ["<!-- plan: status=%s risk=normal accepted=- "
             "routed-from=%s -->" % (status, ident),
             "", "# %s routed candidate" % ident, "",
             "Routed body text.", "", "## Steps", "",
             "- [ ] do the thing", "      Verification: check", ""]
    if occurrences:
        lines.append("## Occurrences")
        lines.append("")
        for i in range(occurrences):
            lines.append("- 2026-09-14T%02d:00:00Z re-occurred "
                         "(dedup window expired)" % (10 + i))
        lines.append("")
    return "\n".join(lines), "%s-routed-%s.plan.md" % (slug_date, ident)


class AlertLifecycle(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name)
        self.kernel = self.root / "kernel"
        self.plans = self.kernel / "docs" / "project" / "plans"
        self.plans.mkdir(parents=True)
        self.auto = self.root / "auto"
        self.auto.mkdir()
        self.queue = self.root / "queue.sh"
        self.queue.write_text(
            "#!/usr/bin/env bash\n"
            # emulate report-queue identity dedup: window-0 identity
            # (--window 0) fires one row per identity ever
            "ID=$(printf '%s\\n' \"$*\" | sed -n 's/.*--identity \\([^ ]*\\).*/\\1/p')\n"
            "if printf '%s\\n' \"$*\" | grep -q -- '--window 0' && "
            "grep -q -- \"--identity $ID \" " + str(self.root / "queue.log") +
            " 2>/dev/null; then exit 0; fi\n"
            "printf '%s\\n' \"$*\" >> " + str(self.root / "queue.log") + "\n")
        self.queue.chmod(0o755)
        self.state = self.root / "STATE.md"
        self.base_env = {
            **os.environ,
            "HNGH_HOME": str(self.kernel),
            "HNGH_AUTOMATION_ROOT": str(self.auto),
            "HNGH_REPORT_QUEUE": str(self.queue),
            "HNGH_REPORT_ROOT": str(self.kernel),
            "STATE_FILE": str(self.state),
        }

    def tearDown(self):
        self._td.cleanup()

    def tick(self, identity, text="", **extra):
        env = {**self.base_env, **extra}
        return subprocess.run(
            [sys.executable, "-B", str(TICK),
             "--identity", identity, "--text", text],
            env=env, capture_output=True, text=True, timeout=60)

    def rows(self):
        log = self.root / "queue.log"
        if not log.exists():
            return []
        out = []
        for line in log.read_text().splitlines():
            m = re.search(r"--identity (\S+)", line)
            if m:
                out.append(m.group(1))
        return out

    def plan_status(self, path):
        return re.search(r"status=(\w+)",
                         path.read_text()[:400]).group(1)

    def age_plan(self, path, hours):
        old = time.time() - hours * 3600
        os.utime(path, (old, old))

    # --- CANDIDATE EXPIRY -------------------------------------------

    def test_expiry_marks_candidate_and_files_one_row(self):
        text, name = routed_candidate()
        plan = self.plans / name
        plan.write_text(text)
        self.age_plan(plan, 25)  # past default 24h TTL
        rc = self.tick("gate:make-test").returncode
        self.assertEqual(rc, 0)
        self.assertEqual(self.plan_status(plan), "expired")
        # exactly one expiry row, unlimited-lookback identity
        exp = [r for r in self.rows() if "routed-expired" in r]
        self.assertEqual(len(exp), 1)
        self.assertIn(name[:-8], exp[0])

    def test_young_candidate_not_expired(self):
        text, name = routed_candidate()
        plan = self.plans / name
        plan.write_text(text)
        self.age_plan(plan, 2)
        self.tick("gate:make-test")
        self.assertEqual(self.plan_status(plan), "proposed")
        self.assertFalse([r for r in self.rows() if "routed-expired" in r])

    def test_ttl_env_override(self):
        text, name = routed_candidate()
        plan = self.plans / name
        plan.write_text(text)
        self.age_plan(plan, 2)  # young, but TTL=1h
        self.tick("gate:make-test", HNGH_ROUTER_TTL_HOURS="1")
        self.assertEqual(self.plan_status(plan), "expired")

    def test_ttl_params_tsv_override(self):
        (self.auto / "cadence-params.tsv").write_text(
            "# comment\nrouted-candidate-ttl-hours\t0.5\tx\ty\n")
        text, name = routed_candidate()
        plan = self.plans / name
        plan.write_text(text)
        self.age_plan(plan, 1)  # young vs 24h, old vs 0.5h
        self.tick("gate:make-test")
        self.assertEqual(self.plan_status(plan), "expired")

    def test_expiry_never_touches_accepted_or_terminal(self):
        for status in ("accepted", "executed", "rejected"):
            text, name = routed_candidate(status=status)
            plan = self.plans / name
            plan.write_text(text)
            self.age_plan(plan, 48)
            self.tick("gate:make-test")
            self.assertEqual(self.plan_status(plan), status,
                             "status=%s must not be expired" % status)

    def test_repeat_expiry_fires_single_row(self):
        text, name = routed_candidate()
        plan = self.plans / name
        plan.write_text(text)
        self.age_plan(plan, 25)
        for _ in range(3):
            self.tick("gate:make-test")
        exp = [r for r in self.rows() if "routed-expired" in r]
        self.assertEqual(len(exp), 1)

    # --- ESCALATION ON RECURRENCE -----------------------------------

    def test_expired_refire_escalates_immediately_and_routes_fresh(self):
        text, name = routed_candidate(occurrences=2)
        plan = self.plans / name
        plan.write_text(text)
        self.age_plan(plan, 25)
        # first tick expires the candidate; second tick re-fires it
        self.tick("gate:make-test")
        rc = self.tick("gate:make-test").returncode
        self.assertEqual(rc, 0)
        rows = self.rows()
        esc = [r for r in rows if r.startswith("router:escalated:")]
        self.assertEqual(len(esc), 1)
        # escalation carries recurrence count + oldest occurrence ts
        log = (self.root / "queue.log").read_text()
        line = [l for l in log.splitlines()
                if "router:escalated:gate:make-test" in l][0]
        self.assertIn("re-fired 2x", line)  # recurrence count
        self.assertIn("2026-09-14T10:00:00Z", line)  # oldest occurrence
        # the alert routed fresh past the expired candidate
        fresh = [p for p in self.plans.iterdir()
                 if p.name.endswith(".plan.md")
                 and p.name != name]
        self.assertEqual(len(fresh), 1)
        self.assertEqual(self.plan_status(fresh[0]), "proposed")

    def test_no_escalation_below_threshold(self):
        text, name = routed_candidate()
        plan = self.plans / name
        plan.write_text(text)
        # young live candidate, one suppression: plain dedup, no escalate
        self.tick("gate:make-test")  # draft
        self.tick("gate:make-test")  # suppress
        rows = self.rows()
        self.assertTrue(any(r.startswith("router:dedup:") for r in rows))
        self.assertFalse(any(r.startswith("router:escalated:") for r in rows))
        self.assertEqual(self.plan_status(plan), "proposed")

    def test_escalation_threshold_env_override(self):
        text, name = routed_candidate(occurrences=1)
        plan = self.plans / name
        plan.write_text(text)
        self.age_plan(plan, 25)
        self.tick("gate:make-test", HNGH_ROUTER_ESCALATE_N="1")
        self.tick("gate:make-test")
        esc = [r for r in self.rows() if r.startswith("router:escalated:")]
        self.assertEqual(len(esc), 1)


class IdentityExpiry(unittest.TestCase):
    """Terminal silence (P1d, 2026-09-25): identity rows carry
    expires=<ts> in their text (default first-seen + 7d). A re-fire past
    expiry escalates ONCE (one `expired:<ident>` alert row for the
    operator, plain filing dropped); every further re-fire is silent."""

    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.td = Path(self._td.name)
        self.state = self.td / "identities.json"
        self._saved_env = os.environ.get("HNGH_REPORT_IDENTITIES")
        os.environ["HNGH_REPORT_IDENTITIES"] = str(self.state)
        self.calls = self.td / "calls.log"
        self.calls.write_text("")
        self.rq = self.td / "rq"
        self.rq.write_text(
            "#!/usr/bin/env bash\n"
            "printf '%%s\\n' \"$*\" >> '%s'\n"
            "exit 0\n" % self.calls)
        self.rq.chmod(0o755)

    def tearDown(self):
        if self._saved_env is None:
            del os.environ["HNGH_REPORT_IDENTITIES"]
        else:
            os.environ["HNGH_REPORT_IDENTITIES"] = self._saved_env
        self._td.cleanup()

    def _report(self, text="cond", identity="cron:x", **kw):
        return report_queue.report("alert", text, identity=identity,
                                   window=60, binary=str(self.rq), **kw)

    def _calls(self):
        return [ln for ln in self.calls.read_text().splitlines() if ln]

    def _seed(self, identity="cron:x", expires="2020-01-01T00:00:00Z",
              escalated=False):
        self.state.write_text(json.dumps(
            {identity: {"expires": expires, "escalated": escalated}}))

    def test_first_filing_carries_expires_token(self):
        self.assertTrue(self._report())
        lines = self._calls()
        self.assertEqual(len(lines), 1)
        self.assertRegex(
            lines[0],
            r"^--add alert cond expires=\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z"
            r" --identity cron:x --window 60$")

    def test_refire_within_expiry_still_files(self):
        self.assertTrue(self._report())
        self.assertTrue(self._report())
        self.assertEqual(len(self._calls()), 2)

    def test_post_expiry_escalates_once_then_silent(self):
        self._seed()
        self.assertFalse(self._report())  # escalation replaces the filing
        lines = self._calls()
        self.assertEqual(len(lines), 1)
        self.assertIn("identity expired: cron:x", lines[0])
        self.assertIn("--identity expired:cron:x", lines[0])
        self.assertFalse(self._report())
        self.assertEqual(len(self._calls()), 1)  # silent

    def test_non_identity_rows_untouched(self):
        self.assertTrue(report_queue.report("alert", "plain",
                                            binary=str(self.rq)))
        self.assertEqual(self._calls(), ["--add alert plain"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
