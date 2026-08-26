#!/usr/bin/env python3
"""evolve-dashboard-style: hermetic evolution-loop test.

Runs the real script in the real repo (read-only outputs it controls:
the ui-grades.md ledger append and the current-overlay.json mount).
Assertions cover the determinism contract, generation bounding, the
self-grade ledger rows, and the mounted fittest overlay being loadable.
No fixtures, no mocks — the suite reads the actual artifacts it writes.
"""
import importlib.machinery
import importlib.util
import json
import os
import re
import subprocess
import sys
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = ROOT / "scripts" / "evolve-dashboard-style"
OVERLAY = ROOT / "docs" / "design" / "ui-evolve" / "current-overlay.json"
LEDGER = ROOT / "docs" / "project" / "ui-grades.md"

# Save/restore the real mount + ledger so the test never leaves noise.
_SAVED_OVERLAY = OVERLAY.read_bytes() if OVERLAY.exists() else None
_SAVED_LEDGER = LEDGER.read_bytes() if LEDGER.exists() else None


def load_script():
    mod = importlib.machinery.SourceFileLoader(
        "evolve_dashboard_style", str(SCRIPT))
    name = "evolve_dashboard_style_test"
    loader = importlib.machinery.SourceFileLoader(name, str(SCRIPT))
    spec = importlib.util.spec_from_loader(name, loader)
    m = importlib.util.module_from_spec(spec)
    loader.exec_module(m)
    return m


def run(args):
    return subprocess.run([sys.executable, str(SCRIPT)] + args,
                          capture_output=True, text=True, cwd=ROOT)


def ledger_rows_since(start):
    if not LEDGER.exists():
        return []
    rows = []
    for ln in LEDGER.read_text(encoding="utf-8").splitlines():
        ln = ln.strip()
        if ln.startswith("|") and not ln.startswith("|---") \
                and "timestamp" not in ln:
            rows.append(ln)
    return rows


class TestEvolveDashboardStyle(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.mod = load_script()

    def tearDown(self):
        # restore the mount + ledger after each test
        if _SAVED_OVERLAY is not None:
            OVERLAY.write_bytes(_SAVED_OVERLAY)
        elif OVERLAY.exists():
            OVERLAY.unlink()
        if _SAVED_LEDGER is not None:
            LEDGER.write_bytes(_SAVED_LEDGER)
        else:
            LEDGER.write_text(
                self.mod.LEDGER_HEADER + "\n|---|---|---|---|\n")

    def test_help_mentions_script(self):
        p = run(["--help"])
        self.assertEqual(p.returncode, 0)
        self.assertIn("evolve-dashboard-style", p.stdout)

    def test_determinism_same_seed_identical(self):
        a = run(["--preset", "hngh", "--gens", "3", "--seed", "9"])
        b = run(["--preset", "hngh", "--gens", "3", "--seed", "9"])
        self.assertEqual(a.returncode, 0)
        self.assertEqual(a.stdout, b.stdout)
        self.assertEqual(a.stderr, b.stderr)
        self.assertEqual(len(re.findall(r"^gen \d+:", a.stdout, re.M)), 3)

    def test_gens_bounded_by_cap(self):
        p = run(["--preset", "matrix", "--gens", "999", "--no-mount"])
        self.assertEqual(p.returncode, 0)
        # hard cap MAX_GENS enforced
        self.assertEqual(len(re.findall(r"^gen \d+:", p.stdout, re.M)),
                         self.mod.MAX_GENS)

    def test_self_grade_writes_ledger_and_mount(self):
        before = len(ledger_rows_since(0))
        p = run(["--preset", "ocean", "--gens", "2", "--seed", "5"])
        self.assertEqual(p.returncode, 0)
        # ledger gained N rows with the expected target/grade shape
        rows = ledger_rows_since(0)
        self.assertEqual(len(rows), before + 2)
        last = rows[-1]
        self.assertRegex(last, r"\|\s\d{4}-\d{2}-\d{2} \d{2}:\d{2} \| "
                                  r"dashboard-tui-ocean-gen2 \| \d+/10 \|")
        # mount exists, valid json, matching preset, scored grade
        self.assertTrue(OVERLAY.exists())
        doc = json.loads(OVERLAY.read_text(encoding="utf-8"))
        self.assertEqual(doc["preset"], "ocean")
        self.assertIn(doc["gen"], (1, 2))
        self.assertRegex(doc["grade"], r"\d+/10")
        self.assertIn("fields", doc)

    def test_needs_no_repo_state_for_self_grade(self):
        # self-grade path is hermetic by construction: no grade-interface,
        # no capture, no vision server. Runs fully offline.
        p = run(["--preset", "paper", "--gens", "1", "--seed", "2",
                 "--no-mount"])
        self.assertEqual(p.returncode, 0)
        self.assertIn("gen 1:", p.stdout)


if __name__ == "__main__":
    unittest.main()