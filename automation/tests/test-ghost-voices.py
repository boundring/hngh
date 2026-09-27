#!/usr/bin/env python3
"""test-ghost-voices.py — hermetic tests for lib/ghost-voices.py
(course-correction slice 4). Stubs the bridge; never calls a model."""

import importlib.util
import os
import sys
import tempfile
import time
import unittest

AUTO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD = os.path.join(AUTO, "lib", "ghost-voices.py")


def load_mod():
    spec = importlib.util.spec_from_file_location("ghost_voices", MOD)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class GhostVoicesTest(unittest.TestCase):
    def setUp(self):
        self.td = tempfile.mkdtemp(prefix="ghost-test-")
        self.state = os.path.join(self.td, "ghost-state")
        self.stub = os.path.join(self.td, "stub.txt")
        os.environ["HNGH_GHOST_STATE"] = self.state
        os.environ.pop("HNGH_GHOST_TSV", None)
        os.environ.pop("HNGH_XIAOMI_CMD", None)
        with open(self.stub, "w") as fh:
            fh.write("  Keep the\n ledger honest, operator.\n")
        os.environ["HNGH_GHOST_STUB"] = self.stub
        self.gv = load_mod()

    def tearDown(self):
        for k in ("HNGH_GHOST_STATE", "HNGH_GHOST_STUB",
                  "HNGH_GHOST_TSV", "HNGH_XIAOMI_CMD"):
            os.environ.pop(k, None)

    def stamp(self, age_s=0):
        os.makedirs(self.state, exist_ok=True)
        fp = os.path.join(self.state, "s%d" % time.monotonic_ns())
        open(fp, "w").close()
        past = time.time() - age_s
        os.utime(fp, (past, past))

    def test_roster_loads_full_pantheon(self):
        ghosts = self.gv.load_ghosts()
        self.assertEqual(len(ghosts), 39)
        for g in ghosts:
            self.assertTrue(g["name"] and g["era"] and g["register"]
                            and g["convictions"])
        names = {g["name"] for g in ghosts}
        for want in ("George Orwell", "Franz Kafka", "Stanisław Lem",
                     "Ludwig Wittgenstein"):
            self.assertIn(want, names)

    def test_pick_deterministic_distinct(self):
        ghosts = self.gv.load_ghosts()
        a = [g["name"] for g in self.gv.pick_ghosts(ghosts, "2026-09-27-0")]
        b = [g["name"] for g in self.gv.pick_ghosts(ghosts, "2026-09-27-0")]
        self.assertEqual(a, b)
        self.assertEqual(len(a), 3)
        self.assertEqual(len(set(a)), 3)

    def test_cap_blocks_at_six_fresh(self):
        for _ in range(6):
            self.stamp()
        self.assertIsNone(self.gv.ghost_counsel())
        self.assertEqual(len(os.listdir(self.state)), 6)

    def test_cap_ignores_old_stamps(self):
        for _ in range(6):
            self.stamp(age_s=self.gv.CAP_WINDOW_S + 3600)
        line = self.gv.ghost_counsel()
        self.assertEqual(line, "Keep the ledger honest, operator.")
        fresh = [f for f in os.listdir(self.state)
                 if time.time() - os.path.getmtime(
                     os.path.join(self.state, f)) < self.gv.CAP_WINDOW_S]
        self.assertEqual(len(fresh), 1)

    def test_bridge_failure_fail_closed(self):
        os.environ.pop("HNGH_GHOST_STUB", None)
        os.environ["HNGH_XIAOMI_CMD"] = "exit 7"
        self.assertIsNone(self.gv.ghost_counsel())
        self.assertEqual(os.listdir(self.state), [])

    def test_empty_answer_fail_closed(self):
        open(self.stub, "w").close()
        self.assertIsNone(self.gv.ghost_counsel())
        self.assertEqual(os.listdir(self.state), [])


if __name__ == "__main__":
    unittest.main()
