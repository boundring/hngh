#!/usr/bin/env python3
"""Driver route smoke: --route validation across the two drivers.

The route knob is operator glue: --route=auto|local|remote is the only
closed vocabulary, anything else is malformed (exit 2), and the two
drivers keep their established exit contracts when a route is supplied
(worker-driver without ports refuses no-worker-transport exit 1;
rotate-queue without a reviewer or reachable route exits 2). Route
resolution performs no network when no configs exist, so the suite
stays offline.
"""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent


def run_script(script, args):
    return subprocess.run(["sbcl", "--script", str(ROOT / "scripts" / script), *args],
                          capture_output=True, text=True, cwd=ROOT)


def check(cond, msg):
    if not cond:
        raise AssertionError(msg)


# rotate-queue: usage requires a reviewer or a route
out = run_script("rotate-queue", ["--store=/tmp/x", "--item=x", "objective", "file"])
check(out.returncode == 2, f"rotate-queue without reviewer/route should be exit 2: {out.stdout}")
check("--reviewer=FILE | --route=" in out.stdout, "usage mentions the route form")

# rotate-queue: bad route value is malformed before any probing
out = run_script("rotate-queue", ["--store=/tmp/x", "--item=x", "--route=bogus",
                                  "objective", "file"])
check(out.returncode == 2, f"rotate-queue bogus route should exit 2 (got {out.returncode})")
check("auto, local, or remote" in out.stdout, "route vocabulary error names the closed set")

# worker-driver: --help still exits 0
out = run_script("worker-driver", ["--help"])
check(out.returncode == 0, "worker-driver --help should exit 0")

# worker-driver: bogus route is malformed
out = run_script("worker-driver", ["--store=/tmp/x", "--route=bogus", "objective", "task"])
check(out.returncode == 2, f"worker-driver bogus route should exit 2 (got {out.returncode})")

# worker-driver: with a route, a bare cycle still refuses no-worker (exit 1)
import tempfile
import shutil
with tempfile.TemporaryDirectory() as td:
    out = run_script("worker-driver", [f"--store={td}", "--route=auto",
                                       "objective", "task"])
    check(out.returncode == 1,
          f"bare worker-driver cycle with --route=auto should refuse exit 1 (got {out.returncode})")
    check("no-worker-transport" in out.stdout, "refusal names no-worker-transport")

print("driver route smoke OK (rotate-queue + worker-driver route vocabulary + bare-cycle refusal)")