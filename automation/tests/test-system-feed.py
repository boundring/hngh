#!/usr/bin/env python3
"""test-system-feed.py -- probe_uptime unit proofs (plan 2026-09-09
step 6 residual delta: the System feed needs uptime/last-boot fields).

Cases: /proc/uptime seconds parse (float -> int), `uptime -p`/`-s`
passthrough, fail-closed note on unreadable or garbage /proc, and null
human/last_boot when the uptime binary is missing (seconds survive).
Hermetic: tmp fixture files + stubbed run(); no host state, no network.
"""
import importlib.util
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parent.parent  # automation/


def _load(name, rel):
    spec = importlib.util.spec_from_file_location(name, str(ROOT / rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


sf = _load("system_feed", "jobs/system-feed.py")


def _proc_file(testcase, text):
    f = tempfile.NamedTemporaryFile("w", suffix=".proc", delete=False)
    f.write(text)
    f.close()
    testcase.addCleanup(os.unlink, f.name)
    return f.name


class ProbeUptime(unittest.TestCase):
    """probe_uptime: seconds from /proc/uptime, human/boot from uptime."""

    def test_parses_seconds_and_passthrough(self):
        path = _proc_file(self, "12345.67 23456.78\n")
        with mock.patch.object(
                sf, "run",
                side_effect=[("up 3 days, 4 hours", 0),
                             ("2026-09-11 21:07:52", 0)]):
            val, note = sf.probe_uptime(path)
        self.assertIsNone(note)
        self.assertEqual(val, {"seconds": 12345,
                               "human": "up 3 days, 4 hours",
                               "last_boot": "2026-09-11 21:07:52"})

    def test_fail_closed_on_unreadable_proc(self):
        val, note = sf.probe_uptime("/no/such/uptime")
        self.assertIsNone(val)
        self.assertIn("omitted", note)

    def test_garbage_proc_omits(self):
        path = _proc_file(self, "not-a-number\n")
        val, note = sf.probe_uptime(path)
        self.assertIsNone(val)
        self.assertIn("omitted", note)

    def test_missing_uptime_binary_yields_null_human_and_boot(self):
        # run() seam contract: ("", 127) for a missing tool; seconds survive.
        path = _proc_file(self, "12345.67 23456.78\n")
        with mock.patch.object(sf, "run", side_effect=[("", 127), ("", 127)]):
            val, note = sf.probe_uptime(path)
        self.assertIsNone(note)
        self.assertEqual(val, {"seconds": 12345, "human": None,
                               "last_boot": None})


if __name__ == "__main__":
    unittest.main(verbosity=2)
