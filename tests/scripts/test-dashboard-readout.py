#!/usr/bin/env python3
"""dashboard-readout smoke: the readout runs and reports the timeline rows."""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent


def test_readout_runs():
    out = subprocess.run(
        [sys.executable, str(ROOT / "scripts" / "dashboard-readout")],
        capture_output=True, text=True, cwd=ROOT)
    assert out.returncode == 0, out.stderr
    assert "timeline rows" in out.stdout


if __name__ == "__main__":
    test_readout_runs()
    print("dashboard-readout smoke OK")
