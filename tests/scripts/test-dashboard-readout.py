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


def test_burst():
    out = run(["--burst"])
    assert out.returncode == 0, out.stderr
    assert "burst" in out.stdout


def test_wave():
    out = run(["--wave"])
    assert out.returncode == 0, out.stderr
    assert "wave" in out.stdout


def test_themes():
    for extra in (["--theme=matrix"], ["--banner", "--theme=ocean"], ["--quiet"]):
        out = run(extra)
        assert out.returncode == 0, out.stderr


def test_tone():
    for style in (["--tone"], ["--tone", "--circular"], ["--tone", "--wave"]):
        out = run(style)
        assert out.returncode == 0, out.stderr


def test_dance():
    for style in ([], ["--spiral"], ["--circular"]):
        out = run([*style, "--dance", "5"])
        assert out.returncode == 0, out.stderr
        out = run([*style, "--dance", "auto"])
        assert out.returncode == 0, out.stderr


if __name__ == "__main__":
    test_linear()
    test_spiral()
    test_circular()
    test_burst()
    test_wave()
    test_tone()
    test_dance()
    print("dashboard-readout smoke OK (linear+spiral+circular+burst+wave+tone+theme+banner+quiet+dance)")
