#!/usr/bin/env python3
"""overnight session-launch economics, hermetic (no real sessions, no spend).

The spend cap is a chain — env OVERNIGHT_MAX_SESSIONS_DAY > Inventory row
sessions-day-max > legacy constant 4 — and it gates real delegated
sessions. The launcher (lib/launch-session.sh) regenerates a pre-digested
repo-context pointer fresh at every launch and carries its path in the
session brief. The whole cycle runs in a sandbox copy of scripts/ +
lib/ with stub bridge/omp — nothing real is ever launched.
"""

import os
import shutil
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

AUTO = Path(__file__).resolve().parent.parent

PLAN = """<!-- plan: status=accepted risk=normal author=operator -->
# seed plan

## Steps

- [ ] touch the sandbox marker -- verify: marker exists
"""

LIB = ("common.sh", "breadcrumbs.sh", "causes.sh", "notify-email.sh",
       "params.sh", "context-pack.sh", "launch-session.sh",
       "model.sh", "failfirst.sh")


class SessionLaunch(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.td = Path(self._td.name)
        self.auto = self.td / "automation"
        (self.auto / "lib").mkdir(parents=True)
        (self.auto / "scripts").mkdir()
        (self.auto / "logs").mkdir()
        for f in LIB:
            shutil.copy(AUTO / "lib" / f, self.auto / "lib" / f)
        shutil.copy(AUTO / "scripts" / "overnight-cycle.sh",
                    self.auto / "scripts" / "overnight-cycle.sh")
        shutil.copy(AUTO / "scripts" / "accept-plans.py",
                    self.auto / "scripts" / "accept-plans.py")
        self.kernel = self.td / "kernel"
        (self.kernel / "docs" / "project" / "plans").mkdir(parents=True)
        self.marker = self.td / "launched.marker"
        self.bridge = self.td / "bridge-stub.sh"
        self.bridge.write_text('#!/usr/bin/env bash\n'
                               'echo "run run-42 started $*"\n')
        self.omp = self.td / "omp-stub.sh"
        self.omp.write_text('#!/usr/bin/env bash\n'
                            'printf "%s\\n" "$*" >> "$MARKER"\nexit 0\n')
        self.bridge.chmod(0o755)
        self.omp.chmod(0o755)

    def tearDown(self):
        self._td.cleanup()

    def params(self, row):
        if row is None:
            return
        (self.auto / "cadence-params.tsv").write_text(
            "# Inventory\nsessions-day-max\t%s\ttest\ttest row\n" % row)

    def budget(self, n):
        today = time.strftime("%Y-%m-%d", time.gmtime())
        rows = "".join(
            "%sT00:0%d:00Z | overnight|seed-%d | session-run\n" % (today, i, i)
            for i in range(n))
        (self.auto / "logs" / "budget.md").write_text(rows)

    def plan(self):
        (self.kernel / "docs" / "project" / "plans" / "seed.plan.md"
         ).write_text(PLAN)

    def stale_context(self):
        d = self.auto / "prompts" / "overnight"
        d.mkdir(parents=True)
        (d / "seed.context.txt").write_text("STALE")

    def run_cycle(self, **extra):
        env = dict(os.environ,
                   HNGH_HOME=str(self.kernel),
                   OVERNIGHT_LOCK=str(self.td / "cycle.lock"),
                   OVERNIGHT_TIMEOUT="5",
                   FAILFIRST_STATE_DIR=str(self.td / "ff"),
                   MARKER=str(self.marker),
                   OMP_BRIDGE_BIN=str(self.bridge),
                   OMP_BIN_CMD=str(self.omp))
        env.update(extra)
        return subprocess.run(
            ["bash", str(self.auto / "scripts" / "overnight-cycle.sh")],
            env=env, capture_output=True, text=True, timeout=120)

    def launches(self):
        if not self.marker.exists():
            return 0
        return self.marker.read_text().count("-p --model")

    def test_cap_read_from_inventory_respected(self):
        self.params("8")
        self.budget(7)  # 7 < 8: launches (legacy 4 would have blocked)
        self.plan()
        self.stale_context()
        self.run_cycle()
        self.assertEqual(self.launches(), 1)
        ctx = self.auto / "prompts" / "overnight" / "seed.context.txt"
        body = ctx.read_text()
        self.assertNotIn("STALE", body)  # regenerated fresh at launch
        self.assertIn("regenerated", body)
        self.assertIn(str(self.auto), body)  # pre-digested repo map

    def test_brief_carries_context_pointer(self):
        self.params("8")
        self.budget(7)
        self.plan()
        self.run_cycle()
        self.assertEqual(self.launches(), 1)
        marker = self.marker.read_text()
        self.assertIn("prompts/overnight/seed.context.txt", marker)

    def test_brief_carries_context_pack(self):
        """The pack path is present in the prompt and the pack is the
        generalized context pack (role header + frontier)."""
        self.params("8")
        self.budget(7)
        self.plan()
        self.run_cycle()
        self.assertEqual(self.launches(), 1)
        ctx = self.auto / "prompts" / "overnight" / "seed.context.txt"
        body = ctx.read_text()
        self.assertIn("# context pack — role=overnight-lead seed", body)
        self.assertIn("role hint: ", body)
        marker = self.marker.read_text()
        self.assertIn(str(ctx), marker)  # pack path present in prompt

    def test_cap_enforced_at_inventory_value(self):
        self.params("8")
        self.budget(8)  # 8 >= 8: blocked
        self.plan()
        self.run_cycle()
        self.assertEqual(self.launches(), 0)

    def test_env_override_beats_inventory(self):
        self.params("8")
        self.budget(7)
        self.plan()
        self.run_cycle(OVERNIGHT_MAX_SESSIONS_DAY="4")
        self.assertEqual(self.launches(), 0)

    def test_legacy_default_without_inventory(self):
        self.params(None)  # no Inventory file: legacy constant 4
        self.budget(7)
        self.plan()
        self.run_cycle()
        self.assertEqual(self.launches(), 0)

    # --- fail-first development tier: concurrency tunes within the cap ---

    def ff_seed(self, speed=1, age=0):
        """Pre-seed the development failfirst state (key=value format)."""
        d = self.td / "ff"
        d.mkdir(parents=True, exist_ok=True)
        (d / "failfirst-development").write_text(
            "speed=%d\noks=0\nlast=none\nceiling=0\nlastrun=%d\n"
            "n_ok=0\nn_deg=0\nn_fail=0\n" % (speed, time.time() - age))

    def ff_state(self, key):
        f = self.td / "ff" / "failfirst-development"
        for line in f.read_text().splitlines():
            if line.startswith(key + "="):
                return line.split("=", 1)[1]
        return ""

    def three_plans(self):
        for i in (1, 2, 3):
            (self.kernel / "docs" / "project" / "plans" /
             ("seed%d.plan.md" % i)).write_text(PLAN.replace("seed plan",
                                                             "seed plan %d" % i))

    def test_full_speed_runs_three_concurrent(self):
        """fresh state -> GO at full: all 3 accepted plans launch in one
        beat (concurrency from the Inventory row, cap permitting)."""
        self.params("8")
        self.three_plans()
        self.run_cycle()
        self.assertEqual(self.launches(), 3)

    def test_degraded_paces_the_beat(self):
        """standard speed + a beat just recorded -> THROTTLE: zero
        launches, the plans stay queued for the next beat."""
        self.params("8")
        self.three_plans()
        self.ff_seed(speed=2, age=0)
        self.run_cycle()
        self.assertEqual(self.launches(), 0)

    def test_standard_concurrency_two_after_release(self):
        """standard speed releasing after its 2-tick pace -> 2 concurrent
        sessions (of 3 queued plans)."""
        self.params("8")
        self.three_plans()
        self.ff_seed(speed=2, age=7201)
        self.run_cycle()
        self.assertEqual(self.launches(), 2)

    def test_day_max_caps_concurrency(self):
        """the sessions-day-max hard ceiling sits ABOVE the tuning: full
        speed wants 3 but only 1 slot is left under the cap."""
        self.params("8")
        self.budget(7)
        self.three_plans()
        self.run_cycle()
        self.assertEqual(self.launches(), 1)

    def test_dead_session_demotes_speed(self):
        """a dead session (rc!=0) records degraded -> speed demoted to
        standard in the development state file."""
        self.params("8")
        self.plan()
        failing_omp = self.td / "omp-fail.sh"
        failing_omp.write_text('#!/usr/bin/env bash\nexit 1\n')
        failing_omp.chmod(0o755)
        self.run_cycle(OMP_BIN_CMD=str(failing_omp))
        self.assertEqual(self.ff_state("speed"), "2")
        self.assertEqual(self.ff_state("n_deg"), "1")

    def test_bridge_refusal_records_failed(self):
        """a launch-plane crash (bridge refusal, rc=75) records failed ->
        drop to cautious (speed 3)."""
        self.params("8")
        self.plan()
        refused_bridge = self.td / "bridge-refused.sh"
        refused_bridge.write_text('#!/usr/bin/env bash\necho refused >&2\nexit 1\n')
        refused_bridge.chmod(0o755)
        self.run_cycle(OMP_BRIDGE_BIN=str(refused_bridge))
        self.assertEqual(self.ff_state("speed"), "3")
        self.assertEqual(self.ff_state("n_fail"), "1")


if __name__ == "__main__":
    unittest.main()
