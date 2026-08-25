#!/usr/bin/env python3
"""dashboard-readout smoke: both renderers run and report rows."""

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
    assert "spiral" in out.stdout
    assert "timeline rows" in out.stdout


if __name__ == "__main__":
    test_linear()
    test_spiral()
    print("dashboard-readout smoke OK (linear + spiral)")
