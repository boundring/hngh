#!/usr/bin/env python3
"""Heartbeat smoke: schedule-heartbeat's CLI contract, testable offline.

The contract under test: --dry-run is a pure probe that never mutates
and always exits 0 on a well-formed ledger; the period itself lives in
operator cron/systemd (never inside the script). The dirty-tree refusal
exit is checked without touching the real tree by pointing the script
at a temporary fake tree via monkeypatching the module's ROOT. --loop
is the operator's foreground knob and is not exercised here (it never
completes by design). No network access is required.
"""

import importlib.machinery
import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = ROOT / "scripts" / "schedule-heartbeat"


def load_module():
    loader = importlib.machinery.SourceFileLoader("schedule_heartbeat", str(SCRIPT))
    spec = importlib.util.spec_from_loader("schedule_heartbeat", loader)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def run(args):
    return subprocess.run([sys.executable, str(SCRIPT), *args],
                          capture_output=True, text=True, cwd=ROOT)


class HeartbeatDryRun(unittest.TestCase):
    def test_dry_run_exits_zero_and_mutates_nothing(self):
        before = sorted(p.name for p in (ROOT / "docs" / "project").glob("*.md"))
        out = run(["--dry-run"])
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("next:", out.stdout)
        self.assertIn("tree:", out.stdout)
        self.assertIn("model:", out.stdout)
        after = sorted(p.name for p in (ROOT / "docs" / "project").glob("*.md"))
        self.assertEqual(before, after, "dry-run must not create or remove docs")
        self.assertNotIn("heartbeat-", (ROOT / "docs" / "project" / "timeline.md").read_text())

    def test_help_exits_zero(self):
        out = run(["--help"])
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("schedule-heartbeat", out.stdout)

    def test_bad_route_is_malformed(self):
        out = run(["--route=bogus"])
        self.assertEqual(out.returncode, 2, out.stdout)

    def test_dirty_tree_postpones_exit_one(self):
        # point the module at a disposable fake repo whose queue.md is
        # well-formed but whose git status reports dirty
        mod = load_module()
        with tempfile.TemporaryDirectory() as tmp:
            fake = Path(tmp)
            (fake / "docs" / "project").mkdir(parents=True)
            (fake / "docs" / "project" / "queue.md").write_text(
                "# Queue\n\n```\nid\tstatus\ttitle\tevidence\nitem-a\tqueued\tA\tb\n```\n")
            (fake / "docs" / "project" / "timeline.md").write_text(
                "2026-08-25\tevent\tseed\tdeadbeef\n")
            (fake / "docs" / "project" / "checkin.md").write_text("")
            mod.ROOT = fake
            mod.QUEUE = fake / "docs" / "project" / "queue.md"
            mod.TIMELINE = fake / "docs" / "project" / "timeline.md"
            mod.CHECKIN = fake / "docs" / "project" / "checkin.md"
            mod.RECIPE_DIR = fake / "docs" / "project" / "heartbeat"
            mod.ROUTE_PROBE = fake / "scripts" / "probe-model-route"

            def fake_git(*cmd):
                if cmd[:2] == ("status", "--porcelain"):
                    return 0, " M docs/project/queue.md", ""
                return 0, "", ""

            mod.git = fake_git
            code, _ = mod.tick(True, "auto")
            self.assertEqual(code, 0)  # dry-run does not need a clean tree
            # A real tick on a dirty tree must refuse, exit 1
            code, _ = mod.tick(False, "auto")
            self.assertEqual(code, 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)