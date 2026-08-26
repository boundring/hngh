#!/usr/bin/env python3
"""notify-agent guard: classification is pure, offline-testable.

--classify with a job-search phrase must print `hit:<keyword>`; an
innocuous phrase must print `none`; --help must exit 0. Listening
(`--listen`) is exercised only through a hand-built Notify block parse
so the suite never mounts a real dbus-monitor process.
"""

import subprocess
import sys
import unittest
from pathlib import Path

import importlib.machinery
import importlib.util

ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = ROOT / "scripts" / "notify-agent"


def run(args):
    return subprocess.run([sys.executable, str(SCRIPT), *args],
                          capture_output=True, text=True, cwd=ROOT)


def load():
    loader = importlib.machinery.SourceFileLoader("notify_mod", str(SCRIPT))
    spec = importlib.util.spec_from_loader("notify_mod", loader)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class NotifyAgent(unittest.TestCase):
    def test_classify_job_phrase_hits(self):
        out = run(["--classify", "You have a new interview invitation"])
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertTrue(out.stdout.startswith("hit:"), out.stdout)

    def test_classify_innocuous_returns_none(self):
        out = run(["--classify", "the weather is pleasant today"])
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertEqual(out.stdout.strip(), "none")

    def test_classify_rejection_hits(self):
        out = run(["--classify",
                   "We regret to inform you: your candidacy was rejected"])
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("reject", out.stdout)

    def test_help_exits_zero(self):
        out = run(["--help"])
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("usage", out.stdout.lower())

    def test_parse_notify_blocks_offline(self):
        mod = load()
        sample = (
            'method call time=1 sender=:1.2 -> '
            'destination=org.freedesktop.Notifications serial=1 '
            'path=/org/freedesktop/Notifications; '
            'interface=org.freedesktop.Notifications; member=Notify\n'
            '   string "Firefox"\n'
            '   uint32 5\n'
            '   string ""\n'
            '   string "New job offer"\n'
            '   string "Details inside"\n'
            '\n'
        )
        blocks = list(mod.parse_notify_blocks(sample))
        self.assertEqual(len(blocks), 1)
        self.assertEqual(blocks[0][0], "Firefox")
        self.assertEqual(blocks[0][1], "New job offer")
        self.assertEqual(blocks[0][2], "Details inside")


if __name__ == "__main__":
    unittest.main(verbosity=2)