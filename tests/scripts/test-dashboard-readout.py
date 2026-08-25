#!/usr/bin/env python3
"""dashboard-readout smoke: every renderer + the dance flag run clean."""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent


def run(args):
    return subprocess.run([sys.executable, str(ROOT / "scripts" / "dashboard-readout"), *args],
                          capture_output=True, text=True, cwd=ROOT)


def test_linear():
    out = run([])
    assert out.returncode == 0, out.stderr
    assert "timeline rows" in out.stdout


def test_spiral():
    out = run(["--spiral"])
    assert out.returncode == 0, out.stderr
    assert "spiral" in out.stdout and "timeline rows" in out.stdout


def test_circular():
    out = run(["--circular"])
    assert out.returncode == 0, out.stderr
    assert "circular" in out.stdout and "timeline rows" in out.stdout


def test_dance():
    for style in ([], ["--spiral"], ["--circular"]):
        out = run([*style, "--dance", "5"])
        assert out.returncode == 0, out.stderr


if __name__ == "__main__":
    test_linear()
    test_spiral()
    test_circular()
    test_dance()
    print("dashboard-readout smoke OK (linear + spiral + circular + dance)")
