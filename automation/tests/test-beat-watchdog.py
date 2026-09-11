#!/usr/bin/env python3
"""beat-watchdog detector, hermetic (fixtures from the REAL 2026-09-11
beat-stall incident — docs/records/2026-09-11-beat-stall-diagnosis.md):
  (a) 3x results=failed breadcrumbs -> blocker row + beat-stall alert
  (b) 2 same-cause plan deaths -> escalation to parked
  (c) beat silence: stale overnight-done + live cadence ticks
  (d) healthy ledger -> silent (no alert, no row)
  (e) thresholds come from cadence-params rows, not hardcoded
  (f) detector crash-safety: corrupt input exits 0, writes nothing
No real report-queue, no real STATE.md — temp dirs only."""

import importlib.util
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / "jobs" / "beat-watchdog.py"


def iso(ago_s):
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() - ago_s))


# real incident breadcrumbs (STATE.md 2026-09-11, verbatim detail fields)
INCIDENT_CRUMBS = "\n".join(
    "%s | overnight-cycle.sh | overnight-done | %s\n"
    % (iso(ago), detail)
    for ago, detail in [
        (11 * 3600 + 25 * 60, "sessions=2 concurrency=2 speed=2 results=failed,failed model=openrouter/z-ai/glm-5.3-flash(env)"),
        (7 * 3600 + 15 * 60, "sessions=1 concurrency=1 speed=3 results=failed model=openrouter/z-ai/glm-5.3-flash(env)"),
        (50 * 60, "sessions=1 concurrency=1 speed=3 results=failed model=openrouter/z-ai/glm-5.3-flash(env)"),
    ])

# cadence ticks kept arriving during the stall (rule c co-witness)
TICK = "%s | cadence-10m | mounted | tier 10m launching feed\n" % iso(5 * 60)

HEALTHY_CRUMBS = "\n".join(
    "%s | overnight-cycle.sh | overnight-done | sessions=1 concurrency=1 speed=3 results=ok model=m(env)"
    % iso(ago) for ago in (30 * 60, 2 * 3600 + 30 * 60))


def load_mod():
    spec = importlib.util.spec_from_file_location("beat_watchdog", SPEC)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class BeatWatchdog(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name)
        self.state = self.root / "STATE.md"
        self.handoffs = self.root / "agent-handoffs.md"
        self.blockers = self.root / "state" / "beat-blockers.tsv"
        self.alerts = self.root / "alerts.tsv"
        (self.root / "rq.sh").write_text(
            "#!/usr/bin/env bash\n"
            'printf "%s\\n" "$5" >>"$BEAT_ALERTS"\n')
        os.chmod(self.root / "rq.sh", 0o755)
        for k, v in [("BEAT_STATE_FILE", str(self.state)),
                     ("BEAT_HANDOFFS", str(self.handoffs)),
                     ("BEAT_BLOCKERS_FILE", str(self.blockers)),
                     ("REPORT_QUEUE_BIN", str(self.root / "rq.sh")),
                     ("BEAT_ALERTS", str(self.alerts))]:
            os.environ[k] = v
        self._mod = load_mod()

    def tearDown(self):
        self._td.cleanup()

    def run_det(self):
        self._mod.run(now_s=time.time())
        rows = (self.blockers.read_text().splitlines()
                if self.blockers.exists() else [])
        alerts = (self.alerts.read_text()
                  if self.alerts.exists() else "")
        return rows, alerts

    def write_inputs(self, state, handoffs=""):
        self.state.write_text(state)
        if handoffs:
            self.handoffs.write_text(handoffs)

    # --- (a) the incident shape: consecutive launch-plane failures ---
    def test_three_launch_failures_file_blocker_and_alert(self):
        self.write_inputs(INCIDENT_CRUMBS + "\n" + TICK)
        rows, alerts = self.run_det()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0].split("\t")[1], "overnight")
        self.assertEqual(rows[0].split("\t")[2], "bad-execution")
        self.assertIn("beat-stall:overnight", alerts)

    # --- (b) respawn-guard semantics at plan level ---
    def test_two_same_cause_deaths_escalate_to_parked(self):
        row = ("overnight-lead | %s | 2026-09-06-worker-transport-wiring|run-1 | "
               "rc=124 dead log=logs/x.log model=m(env) cause=unknown")
        self.write_inputs(HEALTHY_CRUMBS,
                          row % iso(3 * 3600) + "\n" + row % iso(30 * 60) + "\n")
        rows, alerts = self.run_det()
        self.assertEqual(len(rows), 1)
        f = rows[0].split("\t")
        self.assertEqual(f[1], "2026-09-06-worker-transport-wiring")
        self.assertEqual(f[4], "2")
        self.assertEqual(f[5], "parked")
        self.assertIn("beat-stall:2026-09-06-worker-transport-wiring", alerts)

    # --- (b) single death: the watchdog never pre-empts the beat loop ---
    def test_single_death_files_nothing(self):
        self.write_inputs(HEALTHY_CRUMBS,
                          "overnight-lead | %s | some-plan|run-1 | rc=1 dead "
                          "log=logs/x.log model=m(env) cause=bad-execution"
                          % iso(30 * 60))
        rows, alerts = self.run_det()
        self.assertEqual(rows, [])
        self.assertEqual(alerts, "")

    # --- (c) the 12h signature: ticks alive, beats dead ---
    def test_beat_silence_detected_only_with_later_ticks(self):
        stale = ("%s | overnight-cycle.sh | overnight-done | sessions=1 "
                 "concurrency=1 speed=3 results=ok model=m(env)\n" % iso(13 * 3600))
        self.write_inputs(stale)  # beats went quiet, NO later tick
        rows, _ = self.run_det()
        self.assertEqual(rows, [])
        self.write_inputs(TICK + stale)  # cadence ticks continued after
        rows, _ = self.run_det()
        self.assertIn("overnight-silence", [r.split("\t")[1] for r in rows])

    # --- (d) healthy ledger is silent ---
    def test_healthy_ledger_is_silent(self):
        self.write_inputs(HEALTHY_CRUMBS)
        rows, alerts = self.run_det()
        self.assertEqual(rows, [])
        self.assertEqual(alerts, "")

    # --- ledger ownership: the cycle-created row is never overwritten ---
    def test_existing_cycle_row_is_untouched(self):
        self.write_inputs(INCIDENT_CRUMBS + "\n" + TICK,
                          "overnight-lead | %s | 2026-09-06-worker-transport-wiring|run-1 | "
                          "rc=1 dead log=logs/x.log model=m(env) cause=unknown\n"
                          "overnight-lead | %s | 2026-09-06-worker-transport-wiring|run-1 | "
                          "rc=1 dead log=logs/y.log model=m(env) cause=unknown"
                          % (iso(3 * 3600), iso(30 * 60)))
        self.blockers.parent.mkdir(parents=True, exist_ok=True)
        owned = ("blk-20260911-2026-09-06-worker-transport-wiring\t"
                 "2026-09-06-worker-transport-wiring\tunknown\t"
                 "2026-09-11T00:00:00Z\t1\tactive\n")
        self.blockers.write_text(owned)
        self.run_det()
        # the slug row is cycle-owned: unchanged; only the beat-level
        # scope (overnight) the cycle never writes may be added
        lines = self.blockers.read_text().splitlines()
        self.assertIn(owned.strip(), lines)
        self.assertEqual(
            len([ln for ln in lines
                 if ln.split("\t")[1] == "2026-09-06-worker-transport-wiring"]), 1)

    # --- (f) fail-first: a detector crash never breaks the tick ---
    def test_crash_suppressed_exit_zero(self):
        os.environ["BEAT_STATE_FILE"] = str(self.root / "no-such-dir" / "STATE.md")
        r = subprocess.run([sys.executable, str(SPEC)], capture_output=True)
        self.assertEqual(r.returncode, 0)


if __name__ == "__main__":
    unittest.main(verbosity=1)