#!/usr/bin/env python3
"""Hermetic tests for system-ingest.py: pure parsers + main smoke.

Parsers take file CONTENT (strings), never /proc paths, so cases are
deterministic. The main() case exercises the real script end to end on
this host (reading /proc is safe, output lands in a temp dir).
"""

import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD = os.path.join(ROOT, "scripts", "system-ingest.py")

_spec = importlib.util.spec_from_file_location("system_ingest", MOD)
si = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(si)


class ParseMeminfo(unittest.TestCase):
    def test_basic(self):
        text = (
            "MemTotal:       65808848 kB\n"
            "MemFree:        12000000 kB\n"
            "MemAvailable:   32000000 kB\n"
            "Buffers:          512000 kB\n"
        )
        m = si.parse_meminfo(text)
        self.assertEqual(m["total_mb"], round(65808848 / 1024, 1))
        self.assertEqual(m["avail_mb"], round(32000000 / 1024, 1))
        self.assertAlmostEqual(m["used_pct"], (1 - 32000000 / 65808848) * 100, places=1)

    def test_missing_available_is_none(self):
        self.assertIsNone(si.parse_meminfo("MemTotal: 1000 kB\nMemFree: 500 kB\n"))

    def test_garbage_is_none(self):
        self.assertIsNone(si.parse_meminfo("not a meminfo file"))


class ParseLoadavg(unittest.TestCase):
    def test_basic(self):
        l = si.parse_loadavg("0.82 0.74 0.69 3/4321 12345")
        self.assertEqual(l, {"load1": 0.82, "load5": 0.74, "load15": 0.69})

    def test_garbage_is_none(self):
        self.assertIsNone(si.parse_loadavg(""))

        self.assertIsNone(si.parse_loadavg("a b c d e"))


class ParseUptime(unittest.TestCase):
    def test_basic(self):
        self.assertEqual(si.parse_uptime("12345.67 23456.78"), round(12345.67, 1))

    def test_garbage_is_none(self):
        self.assertIsNone(si.parse_uptime("soon"))


class ParseNvidiaSmi(unittest.TestCase):
    def test_csv(self):
        g = si.parse_nvidia_smi("1024, 24564, 37")
        self.assertEqual(g, {"used_mb": 1024.0, "total_mb": 24564.0, "util_pct": 37.0})

    def test_garbage_is_none(self):
        self.assertIsNone(si.parse_nvidia_smi("no csv here"))
        self.assertIsNone(si.parse_nvidia_smi(""))


class DiskUsage(unittest.TestCase):
    def test_real_dir(self):
        with tempfile.TemporaryDirectory() as d:
            u = si.disk_usage(d)
            self.assertEqual(u["path"], d)
            self.assertGreaterEqual(u["used_pct"], 0.0)
            self.assertLessEqual(u["used_pct"], 100.0)
            self.assertGreater(u["total_gb"], 0.0)
            self.assertGreaterEqual(u["free_gb"], 0.0)

    def test_missing_path_is_none(self):
        self.assertIsNone(si.disk_usage("/nonexistent/path/for/test"))


class MainSmoke(unittest.TestCase):
    def test_end_to_end(self):
        with tempfile.TemporaryDirectory() as out_dir:
            out = os.path.join(out_dir, "system-resources.json")
            r = subprocess.run(
                [sys.executable, "-B", MOD, "--out", out],
                capture_output=True, text=True, timeout=60,
            )
            self.assertEqual(r.returncode, 0, r.stderr)
            doc = json.load(open(out))
            self.assertIn("generated", doc)
            self.assertIsInstance(doc["disks"], list)
            self.assertGreater(len(doc["disks"]), 0)
            # This host always has memory + load; tolerate exotic absence.
            if doc.get("memory"):
                self.assertIn("used_pct", doc["memory"])
            if doc.get("load"):
                self.assertIn("load1", doc["load"])

    def test_default_output_env_seam(self):
        with tempfile.TemporaryDirectory() as d:
            out = os.path.join(d, "sys.json")
            env = dict(os.environ, HNGH_SYSTEM_STATE=out)
            r = subprocess.run(
                [sys.executable, "-B", MOD],
                capture_output=True, text=True, timeout=60, env=env,
            )
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertTrue(os.path.exists(out))


if __name__ == "__main__":
    unittest.main(verbosity=2)
