#!/usr/bin/env python3
"""billion-context launch routing, hermetic (no real sessions, no spend).

Machine launches must route through the bili proxy exactly the way the
operator's interactive fish wrappers do (hngh
docs/records/2026-08-24-context-budget-and-toolchain.md): launch_session
invokes `bili omp -- <args>` when bili is on PATH, else falls back to
plain omp with a bctx-absent breadcrumb. The respawner inherits the same
path via lib/launch-session.sh (guard 4: one launcher). Binaries are
stubbed with marker-writing scripts — nothing real is ever launched.
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
       "params.sh", "context-pack.sh", "launch-session.sh")

OMP_STUB = ('#!/usr/bin/env bash\n'
            'printf "%s\\n" "$*" >> "$MARKER"\n'
            'printf "session output\\n" > "$2" 2>/dev/null || true\n'
            'exit 0\n')
BILI_STUB = ('#!/usr/bin/env bash\n'
             '# bili wrapper: record the omp args, then delegate\n'
             'printf "bili %s\\n" "$*" >> "$BILI_MARKER"\n'
             '[ "$1" = omp ] && shift\n'
             '[ "${1:-}" = -- ] && shift\n'
             'exec "$OMP_STUB" "$@"\n')
BRIDGE_STUB = ('#!/usr/bin/env bash\n'
               'echo "run run-42 started $*"\n')


class BctxLaunch(unittest.TestCase):
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
        (self.auto / "cadence-params.tsv").write_text(
            "# Inventory\nsessions-day-max\t8\ttest\ttest row\n")
        self.kernel = self.td / "kernel"
        (self.kernel / "docs" / "project" / "plans").mkdir(parents=True)
        (self.kernel / "docs" / "project" / "plans" / "seed.plan.md"
         ).write_text(PLAN)
        self.marker = self.td / "launched.marker"
        self.bili_marker = self.td / "bili.marker"
        self.state = self.auto / "STATE.md"

    def tearDown(self):
        self._td.cleanup()

    def stubs(self, with_bili):
        stubdir = self.td / "stubs"
        stubdir.mkdir()
        # named `omp`: with bili absent, `command -v omp` must find THIS
        # stub, never the real ~/.bun/bin/omp (no real launches, no spend)
        omp = stubdir / "omp"
        omp.write_text(OMP_STUB)
        bridge = stubdir / "bridge-stub.sh"
        bridge.write_text(BRIDGE_STUB)
        env = {
            "OMP_STUB": str(omp),
            "MARKER": str(self.marker),
            "BILI_MARKER": str(self.bili_marker),
            "OMP_BRIDGE_BIN": str(bridge),
            "PATH": "%s:/usr/bin:/bin" % stubdir,
        }
        omp.chmod(0o755)
        bridge.chmod(0o755)
        if with_bili:
            bili = stubdir / "bili"
            bili.write_text(BILI_STUB)
            bili.chmod(0o755)
        return env

    def run_cycle(self, env):
        full = dict(os.environ,
                    HNGH_HOME=str(self.kernel),
                    OVERNIGHT_LOCK=str(self.td / "cycle.lock"),
                    OVERNIGHT_TIMEOUT="5")
        full.update(env)
        return subprocess.run(
            ["bash", str(self.auto / "scripts" / "overnight-cycle.sh")],
            env=full, capture_output=True, text=True, timeout=120)

    def test_bili_present_routes_through_proxy(self):
        env = self.stubs(with_bili=True)
        self.run_cycle(env)
        bili_args = self.bili_marker.read_text()
        # the bili wrapper received the omp args after `omp --`
        self.assertIn("omp -- -p --model", bili_args)
        # and the delegation delivered the real omp args to omp
        self.assertIn("-p --model", self.marker.read_text())
        # no fail-open breadcrumb when bili is present
        if self.state.exists():
            self.assertNotIn("bctx-absent", self.state.read_text())

    def test_bili_absent_falls_back_with_breadcrumb(self):
        env = self.stubs(with_bili=False)
        self.run_cycle(env)
        self.assertIn("-p --model", self.marker.read_text())
        self.assertFalse(self.bili_marker.exists())
        state = self.state.read_text()
        self.assertIn("bctx-absent", state)
        self.assertIn("bctx: bili absent", state)

    def test_respawn_launch_inherits_proxy_path(self):
        root = self.td / "respawn"
        (root / "logs").mkdir(parents=True)
        env = self.stubs(with_bili=True)
        env.update(
            RESPAWN_ROOT=str(root),
            OVERNIGHT_TIMEOUT="5",
            RESPAWN_DAILY_CAP="10",
            RESPAWN_MAX_ATTEMPTS="5",
            OVERNIGHT_MAX_SESSIONS_DAY="99",
            RESPAWN_HANDOFFS=str(root / "agent-handoffs.md"),
        )
        (root / "agent-handoffs.md").write_text(
            "overnight-lead | 2026-09-06T01:00:00Z | seed|run-1 | "
            "rc=124 dead log=logs/overnight-seed-timeout.log "
            "model=zai/glm-5.3(paid-fallback) cause=bad-execution\n")
        subprocess.run(["bash", str(AUTO / "jobs" / "agent-respawn.sh")],
                       env=dict(os.environ, **env), cwd=str(root),
                       capture_output=True, text=True, timeout=120)
        # respawn reaches omp through the same one launch path
        self.assertIn("omp -- -p --model", self.bili_marker.read_text())

    def test_timeout_rc_captured_into_disposition(self):
        """A session the timeout kills (stub exit 124) records dead, not
        cancelled — the cause classifier and respawn guards key on it."""
        env = self.stubs(with_bili=False)
        omp = Path(env["OMP_STUB"])
        omp.write_text('#!/usr/bin/env bash\n'
                       'printf "%s\\n" "$*" >> "$MARKER"\n'
                       "exit 124\n")
        self.run_cycle(env)
        state = self.state.read_text()
        self.assertIn("dead rc=124", state)
        self.assertNotIn("cancelled rc=0", state)


if __name__ == "__main__":
    unittest.main()
