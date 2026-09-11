#!/usr/bin/env python3
"""omp-bridge --propose / --plan-status test, hermetic (plan step 3).

The bridge is invoked as a subprocess with HNGH_BRIDGE_ROOT pointed at a
temp repo (the seam scripts/omp-bridge already supports), so no real
plan file is ever touched. Fail-closed exits follow the house protocol:
2 malformed input, 1 duplicate refusal (never overwrite), 3 fault.
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BRIDGE = ROOT.parent / "scripts" / "omp-bridge"

FRONT = "<!-- plan: status=proposed risk=normal accepted=- -->"


def today():
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


class OmpBridge(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name) / "hngh"
        self.plans = self.root / "docs" / "project" / "plans"
        self.plans.mkdir(parents=True)
        self.env = dict(os.environ, HNGH_BRIDGE_ROOT=str(self.root))

    def tearDown(self):
        self._td.cleanup()

    def run_bridge(self, *args):
        return subprocess.run([sys.executable, str(BRIDGE), *args],
                              env=self.env, capture_output=True, text=True)

    def write_plan(self, name, text):
        (self.plans / name).write_text(text)

    def test_propose_happy_path_writes_exact_front_matter(self):
        r = self.run_bridge("--propose", "demo-feature", "--title", "Demo feature")
        self.assertEqual(r.returncode, 0, r.stderr)
        target = self.plans / f"{today()}-demo-feature.plan.md"
        self.assertTrue(target.exists())
        text = target.read_text()
        self.assertTrue(text.startswith(FRONT + "\n"))
        self.assertIn("# Demo feature", text)
        self.assertIn("omp-bridge --propose", text)
        self.assertEqual(r.stdout.splitlines(), [str(target), FRONT])

    def test_propose_duplicate_exits_1_and_never_overwrites(self):
        existing = self.plans / f"{today()}-demo-feature.plan.md"
        original = FRONT + "\n# Original body\n"
        self.write_plan(existing.name, original)
        r = self.run_bridge("--propose", "demo-feature", "--title", "Demo feature")
        self.assertEqual(r.returncode, 1, r.stderr)
        self.assertEqual(existing.read_text(), original)

    def test_propose_bad_slugs_exit_2(self):
        for slug in ("Bad_Slug", "a" * 65, "caf\xc3\xa9", "-leading", ""):
            r = self.run_bridge("--propose", slug, "--title", "t")
            self.assertEqual(r.returncode, 2, (slug, r.stderr))

    def test_propose_empty_title_exits_2(self):
        for args in (["--propose", "ok-slug", "--title", ""],
                     ["--propose", "ok-slug"]):
            r = self.run_bridge(*args)
            self.assertEqual(r.returncode, 2, r.stderr)

    def test_plan_status_no_arg_returns_array(self):
        self.write_plan("2026-09-10-two.plan.md", FRONT + "\n# two\n")
        r = self.run_bridge("--plan-status")
        self.assertEqual(r.returncode, 0, r.stderr)
        arr = json.loads(r.stdout)
        self.assertEqual([p["slug"] for p in arr], ["2026-09-10-two"])
        self.assertEqual(arr[0]["source"], "frontmatter")

    def test_plan_status_slug_parses_steps(self):
        plan = ("<meta>\n"
                "<!-- plan: status=executed risk=critical "
                "accepted=2026-09-10T01:02:03Z -->\n"
                "# t\n\n## Steps\n\n"
                "- [x] one\n- [ ] two\n- [x] three\n- [x] four\n")
        self.write_plan("2026-09-10-steps.plan.md", plan)
        r = self.run_bridge("--plan-status", "2026-09-10-steps")
        self.assertEqual(r.returncode, 0, r.stderr)
        row = json.loads(r.stdout)
        self.assertEqual(row["status"], "executed")
        self.assertEqual(row["risk"], "critical")
        self.assertEqual(row["accepted"], "2026-09-10T01:02:03Z")
        self.assertEqual(row["steps_total"], 4)
        self.assertEqual(row["steps_done"], 3)

    def test_plan_status_unknown_slug_exits_2(self):
        r = self.run_bridge("--plan-status", "2026-09-10-nonexistent")
        self.assertEqual(r.returncode, 2, r.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
