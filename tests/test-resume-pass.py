#!/usr/bin/env python3
"""resume-pass, hermetic: the cold-resume log is honest about the recovery
surface (dead sessions with cause, held plans, missed day beats, open
operator items) and the sweep gate fires only when the last non-tick
STATE crumb is older than resume-gap-hours."""

import json
import os
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JOB = ROOT / "jobs" / "resume-pass.sh"

DEAD_ROW = ("overnight-lead | 2026-09-06T01:00:00Z | m-dead|run-1 | "
            "rc=124 dead log=logs/x.log cause=bad-execution\n")
PLAN = ("<!-- plan: status=proposed risk=normal -->\n"
        "# 2026-09-05 - held-proposal\n\n## Steps\n\n"
        "- [ ] do the thing -- verify: make test\n")


def iso(ago_s=0):
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() - ago_s))


class ResumePass(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name)
        (self.root / "logs").mkdir()
        (self.root / "cadence" / "day").mkdir(parents=True)
        (self.root / "dashboard").mkdir()
        self.kernel = self.root / "kernel"
        (self.kernel / "docs" / "project" / "plans").mkdir(parents=True)
        self.base_env = dict(
            os.environ, RESUME_ROOT=str(self.root),
            HNGH_KERNEL=str(self.kernel), RESUME_GAP_HOURS="6")

    def run_job(self, mode, **extra):
        env = dict(self.base_env, **extra)
        return subprocess.run(["bash", str(JOB), mode], env=env,
                              capture_output=True, text=True)

    def seed(self, *, crumb_ago=10 * 3600, dead=True, plan=True, items=True):
        state = self.root / "STATE.md"
        state.write_text(f"{iso(crumb_ago)} | credential-health.sh | x | y\n")
        (self.root / "agent-handoffs.md").write_text(DEAD_ROW if dead else "")
        if plan:
            (self.kernel / "docs" / "project" / "plans"
             / "2026-09-05-held-proposal.plan.md").write_text(PLAN)
        for n in ("01-a.sh", "02-b.sh"):
            (self.root / "cadence" / "day" / n).write_text("#!/bin/sh\n")
        if items:
            (self.root / "dashboard" / "operator-items.json").write_text(
                json.dumps({"generated_at": iso(), "items": [
                    {"id": "aaa11111", "text": "some alert",
                     "first_seen": iso(72 * 3600), "status": "open"},
                    {"id": "bbb22222", "text": "fresh alert",
                     "first_seen": iso(3600), "status": "open"}]}))

    def logs(self):
        return sorted((self.root / "logs").glob("resume-*.md"))

    def test_sweep_skips_when_machine_was_up(self):
        self.seed(crumb_ago=600)
        r = self.run_job("--sweep")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.logs(), [])
        self.assertIn("sweep-skip", (self.root / "STATE.md").read_text())

    def test_sweep_fires_after_downtime_and_log_is_honest(self):
        self.seed(crumb_ago=10 * 3600)
        r = self.run_job("--sweep")
        self.assertEqual(r.returncode, 0, r.stderr)
        logs = self.logs()
        self.assertEqual(len(logs), 1)
        text = logs[0].read_text()
        # dead sessions with cause
        self.assertIn("m-dead|run-1", text)
        self.assertIn("cause=bad-execution", text)
        # held plans: re-proposed via accept-plans, noted not acted on
        self.assertIn("2026-09-05-held-proposal.plan.md", text)
        self.assertIn("accept-plans", text)
        # missed day beats listed with the existing catch-up command
        self.assertIn("01-a.sh", text)
        self.assertIn("make adhoc TIER=day", text)
        # open operator items with stale count
        self.assertIn("2 open, 1 stale", text)
        self.assertIn("some alert", text)

    def test_boot_mode_ignores_the_gate(self):
        self.seed(crumb_ago=60, dead=False)
        r = self.run_job("--boot")
        self.assertEqual(r.returncode, 0, r.stderr)
        logs = self.logs()
        self.assertEqual(len(logs), 1)
        self.assertIn("mode=--boot", logs[0].read_text())


if __name__ == "__main__":
    unittest.main()
