#!/usr/bin/env python3
"""agent-respawn guards, hermetic (no real sessions, no real spend).

Every dead row in agent-handoffs.md gets exactly one disposition row, and
the four guards bound the launcher: steer-don't-kill (missing-design /
missing-authority never respawn), loop-break (once per mission per day,
attempts exhausted), budget (daily respawn cap + shared session ledger),
authority (launch only via lib/launch-session.sh). The launcher binaries
are stubbed with marker-writing scripts — nothing real is ever launched.
"""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JOB = ROOT / "jobs" / "agent-respawn.sh"

DEAD = ("overnight-lead | 2026-09-06T01:00:00Z | {slug}|run-1 | "
        "rc=124 dead log=logs/overnight-{slug}-timeout.log model=zai/glm-5.3"
        "(paid-fallback) cause={cause}\n")


def today():
    import time
    return time.strftime("%Y-%m-%d", time.gmtime())


class RespawnGuards(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name)
        (self.root / "logs").mkdir()
        self.handoffs = self.root / "agent-handoffs.md"
        self.marker = self.root / "launched.marker"
        self.base_env = dict(
            os.environ,
            RESPAWN_ROOT=str(self.root),
            RESPAWN_DAILY_CAP="10",
            RESPAWN_MAX_ATTEMPTS="5",
            OVERNIGHT_MAX_SESSIONS_DAY="99",
            MARKER=str(self.marker),
        )

    def run_job(self, **extra):
        env = dict(self.base_env, **extra)
        return subprocess.run(["bash", str(JOB)], env=env,
                              capture_output=True, text=True)

    def stubs(self, tmp):
        """bridge/omp stubs: bridge prints a run id; omp writes the marker."""
        bridge = tmp / "bridge-stub.sh"
        bridge.write_text(
            '#!/usr/bin/env bash\n'
            'printf "%s\\n" "$*" >> "$MARKER"\n'
            'echo "run run-42 started $*"\n')
        omp = tmp / "omp-stub.sh"
        omp.write_text(
            "#!/usr/bin/env bash\n"
            'printf "%s\\n" "$*" >> "$MARKER"\n'
            'printf "session output\\n" > "$2" 2>/dev/null || true\n'
            "exit 0\n")
        bridge.chmod(0o755)
        omp.chmod(0o755)
        return {"OMP_BRIDGE_BIN": str(bridge), "OMP_BIN_CMD": str(omp)}

    def rows(self):
        out = []
        for ln in self.handoffs.read_text().splitlines():
            if ln.startswith("respawn"):
                out.append(ln)
        return out

    def test_missing_design_never_respawns_and_queues_research(self):
        self.handoffs.write_text(DEAD.format(slug="m-des", cause="missing-design"))
        r = self.run_job(**self.stubs(self.root))
        self.assertEqual(r.returncode, 0, r.stderr)
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        self.assertIn("respawn-refused", rows[0])
        self.assertIn("reason=missing-design-not-respawnable", rows[0])
        subjects = (self.root / "research-subjects.txt").read_text()
        self.assertIn("fail-", subjects)
        self.assertIn("m-des", subjects)
        self.assertFalse(self.marker.exists(), "no session may launch")
        self.assertNotIn("\nrespawn | ", self.handoffs.read_text())

    def test_missing_authority_never_respawns(self):
        self.handoffs.write_text(
            DEAD.format(slug="m-auth", cause="missing-authority"))
        r = self.run_job(**self.stubs(self.root))
        self.assertEqual(r.returncode, 0, r.stderr)
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        self.assertIn("reason=missing-authority-operator-packet-exists", rows[0])
        self.assertFalse(self.marker.exists())
        self.assertNotIn("research-subjects", "")

    def test_same_mission_once_per_day(self):
        dead = DEAD.format(slug="m-dup", cause="bad-execution")
        done = (f"respawn | {today()}T00:30:00Z | m-dup|run-0 | "
                "prev-cause=bad-execution brief=prompts/respawn/x.md run=run-9\n")
        self.handoffs.write_text(dead + done)
        r = self.run_job(**self.stubs(self.root))
        self.assertEqual(r.returncode, 0, r.stderr)
        rows = self.rows()
        self.assertEqual(len(rows), 2)  # pre-seeded + one refusal
        self.assertIn("reason=mission-already-respawned-today", rows[-1])
        self.assertFalse(self.marker.exists())

    def test_attempts_exhausted_refused(self):
        self.handoffs.write_text("".join(
            DEAD.format(slug="m-loop", cause="bad-execution")
            .replace("run-1", f"run-{n}") for n in range(1, 4)))
        r = self.run_job(RESPAWN_MAX_ATTEMPTS="2", **self.stubs(self.root))
        self.assertEqual(r.returncode, 0, r.stderr)
        rows = self.rows()
        refused = [x for x in rows if "attempts-exhausted" in x]
        self.assertEqual(len(refused), 1, rows)
        # the first death (0 previous) still launched; only the third is barred
        self.assertEqual(self.marker.read_text().count("-p --model"), 1)

    def test_daily_cap_refused(self):
        self.handoffs.write_text(
            DEAD.format(slug="m-a", cause="bad-execution")
            + DEAD.format(slug="m-b", cause="bad-execution"))
        r = self.run_job(RESPAWN_DAILY_CAP="1", **self.stubs(self.root))
        self.assertEqual(r.returncode, 0, r.stderr)
        rows = self.rows()
        self.assertEqual(len([x for x in rows if x.startswith("respawn | ")]), 1)
        self.assertIn("reason=daily-cap", "".join(rows))
        self.assertEqual(self.marker.read_text().count("-p --model"), 1)

    def test_day_budget_spent_refused(self):
        self.handoffs.write_text(DEAD.format(slug="m-bud", cause="bad-execution"))
        (self.root / "logs" / "budget.md").write_text(
            "".join(f"{today()}T0{i}:00:00Z | overnight|other | session-run\n"
                    for i in range(4)))
        r = self.run_job(OVERNIGHT_MAX_SESSIONS_DAY="4", **self.stubs(self.root))
        self.assertEqual(r.returncode, 0, r.stderr)
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        self.assertIn("reason=day-budget-spent", rows[0])
        self.assertFalse(self.marker.exists())

    def test_happy_path_brief_carries_cause_and_correction(self):
        self.handoffs.write_text(DEAD.format(slug="m-ok", cause="bad-execution"))
        r = self.run_job(**self.stubs(self.root))
        self.assertEqual(r.returncode, 0, r.stderr)
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        self.assertTrue(rows[0].startswith("respawn | "), rows)
        self.assertIn("prev-cause=bad-execution", rows[0])
        self.assertIn("run=run-42", rows[0])
        # the marker: the stub launcher really ran
        self.assertTrue(self.marker.exists(), "stub launcher never invoked")
        self.assertIn("--run-end", self.marker.read_text())
        # the brief: death cause + one concrete corrective instruction
        brief = next((self.root / "prompts" / "respawn").glob("m-ok-*.md"))
        text = brief.read_text()
        self.assertIn("failure-mode: bad-execution", text)
        self.assertIn("correction: run ONE smaller verified step", text)
        self.assertIn("objective: Respawn mission m-ok", text)
        # reorientation block (context manager): pack pointer + cause +
        # corrective — the reborn session orients from the same pack file
        # its launch regenerates (lib/context-pack.sh)
        self.assertIn("reorientation: read the context pack at ", text)
        self.assertIn("prompts/overnight/respawn-m-ok.context.txt", text)
        self.assertIn("cause=bad-execution", text)
        # shared budget ledger got the session-run row (guard 3 accounting)
        self.assertIn("session-run", (self.root / "logs" / "budget.md").read_text())
        self.assertIn("respawn", (self.root / "STATE.md").read_text())

    def test_dead_row_without_cause_is_ignored(self):
        self.handoffs.write_text(
            "overnight-lead | 2026-09-01T01:00:00Z | old|run-1 | "
            "rc=124 dead log=logs/x.log\n")
        r = self.run_job(**self.stubs(self.root))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.rows(), [])
        self.assertFalse(self.marker.exists())


if __name__ == "__main__":
    unittest.main()
