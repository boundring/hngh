#!/usr/bin/env python3
"""report_queue - the one shared report-queue row shim.

One row per report() call behind the kernel scripts/report-queue --add.
The kernel owns the dedup contract: a repeat with the SAME identity
inside window SECONDS bumps the existing row's ` ×N` marker (not a new
row); with evidence, only a changed evidence token re-fires (same
evidence = a stale condition, suppressed). Fail-closed advisory: a lost
row is swallowed (False), never a crash.

usage: report(kind, text, identity=None, window=None, evidence=None,
              binary=None, root=None) -> bool
    True when the row landed (exit 0), False on any fault.
    binary: report-queue path (default <repo>/scripts/report-queue;
    callers pass their own env-seamed constant).
    root: report root injected as HNGH_REPORT_ROOT (default: inherit the
    environment untouched - callers that never injected keep not doing).
"""
import os
import subprocess

REPO = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))


def report(kind, text, identity=None, window=None, evidence=None,
           binary=None, root=None):
    argv = [binary or os.path.join(REPO, "scripts", "report-queue"),
            "--add", kind, text]
    if identity is not None:
        argv += ["--identity", identity]
    if window is not None:
        argv += ["--window", str(window)]
    if evidence:  # the evidence-token policy, single-sourced here
        argv += ["--evidence", evidence]
    env = dict(os.environ, HNGH_REPORT_ROOT=root) if root is not None else None
    try:
        r = subprocess.run(argv, env=env, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, timeout=30)
        return r.returncode == 0
    except Exception:
        return False  # a lost report row must not block the caller
