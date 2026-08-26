#!/usr/bin/env python3
"""backlog-lanes guard: parse backlog.md into lane rows, read-only.

Verifies the on-file behaviors an "active lanes" panel depends on:
--help exits 0 (no args needed); --json parses and yields a summary
where total equals the lane count; the real backlog has at least one
done and one queued lane (existence, not pinned counts); and the --open
filter returns only open lanes. It only verifies — it never rewrites
the backlog or queue.
"""

import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = ROOT / "scripts" / "backlog-lanes"


def run(args):
    return subprocess.run([sys.executable, str(SCRIPT), *args],
                          capture_output=True, text=True, cwd=ROOT)


class BacklogLanes(unittest.TestCase):
    def test_help_exits_zero(self):
        out = run(["--help"])
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("usage", out.stdout.lower())

    def test_json_parses_and_summary_matches(self):
        out = run(["--json"])
        self.assertEqual(out.returncode, 0, out.stderr)
        data = json.loads(out.stdout)
        self.assertIn("generated", data)
        self.assertIn("lanes", data)
        self.assertIn("summary", data)
        self.assertEqual(data["summary"]["total"], len(data["lanes"]))
        for lane in data["lanes"]:
            for key in ("id", "subtitle", "status", "date", "in_queue"):
                self.assertIn(key, lane)

    def test_real_backlog_has_done_and_queued(self):
        out = run(["--json"])
        data = json.loads(out.stdout)
        statuses = {lane["status"] for lane in data["lanes"]}
        self.assertIn("done", statuses)
        self.assertIn("queued", statuses)
        self.assertGreater(data["summary"]["done"], 0)
        self.assertGreater(data["summary"]["queued"], 0)

    def test_open_filter_returns_only_open(self):
        out = run(["--open", "--json"])
        self.assertEqual(out.returncode, 0, out.stderr)
        data = json.loads(out.stdout)
        self.assertTrue(data["lanes"])
        self.assertTrue(all(lane["status"] == "open"
                            for lane in data["lanes"]))
        self.assertEqual(data["summary"]["open"], len(data["lanes"]))


if __name__ == "__main__":
    unittest.main(verbosity=2)