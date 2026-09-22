#!/usr/bin/env python3
"""test-bailiff — charter branch check wiring (plan
2026-09-22-federal-branches-occupancy step 1).

Contract:
  - watch.py --bailiff: rc 0 "bailiff: clean" on a quiet ledger, rc 1
    "bailiff: halt" when the audit yields findings (stale verdicts seeded
    100 versions apart, the watch self-check shape).
  - lib/bailiff.sh bailiff_check: rc mirrors the audit; findings write a
    bailiff-halt breadcrumb; a fault (missing ng dir) fails OPEN (belt,
    not system of record — a bogus probe must never stall every tick).
  - cadence-tick.sh sources bailiff.sh and halts the tier on findings
    (source asserts + live hour-tier smoke over a seeded ledger).
Hermetic: HNGH_LEDGER_DIR points watch.py at a temp ledger; STATE_FILE in
a temp dir; no real ledger reads.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

AUTOMATION = Path(__file__).resolve().parents[1]
WATCH = AUTOMATION / "ng" / "watch.py"
BAILIFF = AUTOMATION / "lib" / "bailiff.sh"
TICK = AUTOMATION / "jobs" / "cadence-tick.sh"

FAILS = 0


def ck(desc: str, expected: object, actual: object) -> None:
    global FAILS
    if expected == actual:
        print(f"ok: {desc}")
    else:
        print(f"FAIL: {desc} (expected={expected!r} actual={actual!r})")
        FAILS += 1


def watch(env: dict, *args: str) -> subprocess.CompletedProcess:
    e = dict(os.environ)
    e.update(env)
    return subprocess.run(
        [sys.executable, str(WATCH), *args], capture_output=True, text=True, env=e
    )


def ledger_with(*rows: dict) -> str:
    d = tempfile.mkdtemp(prefix="hngh-bailiff-test.")
    (Path(d) / "events.jsonl").write_text(
        "".join(json.dumps(r) + "\n" for r in rows), encoding="utf-8"
    )
    return d


def event(kind: str, version: str, pid: str) -> dict:
    return {
        "kind": kind,
        "state_version": version,
        "payload": {"id": pid},
        "created_at": 1.0,
        "refs": (pid,),
    }


# 1) clean ledger -> clean, rc 0
clean = tempfile.mkdtemp(prefix="hngh-bailiff-test.")
r = watch({"HNGH_LEDGER_DIR": clean}, "--bailiff")
ck("clean ledger rc 0", 0, r.returncode)
ck("clean ledger stdout", "bailiff: clean", r.stdout.strip())

# 2) stale verdicts 100 versions apart -> halt, rc 1
stale = ledger_with(
    event("bead.ready", "v00000001", "b1"),
    event("bead.ready", "v00000100", "b2"),
)
r = watch({"HNGH_LEDGER_DIR": stale}, "--bailiff")
ck("stale ledger rc 1", 1, r.returncode)
ck("stale ledger stdout", "bailiff: halt", r.stdout.strip())
ck("stale ledger names the check", 1, r.stderr.count("stale_verdict"))


def bailiff(env: dict, ledger: str) -> subprocess.CompletedProcess:
    e = dict(os.environ)
    e.update(env)
    e["HNGH_LEDGER_DIR"] = ledger
    e.setdefault("AUTOMATION_ROOT", str(AUTOMATION))
    e.setdefault("JOB_NAME", "bailiff-test")
    return subprocess.run(
        ["bash", "-c", '. "$AUTOMATION_ROOT/lib/bailiff.sh"; bailiff_check'],
        capture_output=True, text=True, env=e,
    )


# 3) bailiff_check mirrors the audit
state = tempfile.mkdtemp(prefix="hngh-bailiff-test.")
r = bailiff({"STATE_FILE": state + "/s.tsv"}, clean)
ck("bailiff_check clean rc 0", 0, r.returncode)
ck("bailiff_check clean writes no crumb", "",
   Path(state, "s.tsv").read_text() if Path(state, "s.tsv").exists() else "")

state2 = tempfile.mkdtemp(prefix="hngh-bailiff-test.")
r = bailiff({"STATE_FILE": state2 + "/s.tsv"}, stale)
ck("bailiff_check findings rc 1", 1, r.returncode)
crumb = Path(state2, "s.tsv").read_text() if Path(state2, "s.tsv").exists() else ""
ck("bailiff_check findings crumb", 1,
   sum("bailiff-halt" in line for line in crumb.splitlines()))

# 4) fault fails open (no ng dir under a fake root)
fake = tempfile.mkdtemp(prefix="hngh-bailiff-test.")
os.makedirs(os.path.join(fake, "lib"), exist_ok=True)
for lib in ("bailiff.sh", "breadcrumbs.sh"):
    shutil.copy(AUTOMATION / "lib" / lib, os.path.join(fake, "lib", lib))
state3 = tempfile.mkdtemp(prefix="hngh-bailiff-test.")
r = bailiff({"AUTOMATION_ROOT": fake, "STATE_FILE": state3 + "/s.tsv"}, clean)
ck("fault fails open rc 0", 0, r.returncode)
crumb3 = Path(state3, "s.tsv").read_text() if Path(state3, "s.tsv").exists() else ""
ck("fault crumb names bailiff-fault", 1,
   sum("bailiff-fault" in line for line in crumb3.splitlines()))

# 5) wire asserts: tick sources bailiff and halts the tier
tick_src = TICK.read_text()
ck("tick sources bailiff.sh", 1, tick_src.count("lib/bailiff.sh"))
ck("tick halts on bailiff refusal", 1, tick_src.count("bailiff_check || exit 0"))

# 6) live hour-tier smoke over the seeded ledger: tick exits 0 but bails out
#    before any drop-in (no dropin-fail/tick-done crumb from this tier run).
state4 = tempfile.mkdtemp(prefix="hngh-bailiff-test.")
e = dict(os.environ)
e.update({
    "TIER": "hour",
    "STATE_FILE": state4 + "/s.tsv",
    "HNGH_LEDGER_DIR": stale,
    "JOB_NAME": "bailiff-smoke",
})
r = subprocess.run(["bash", str(TICK)], capture_output=True, text=True, env=e)
ck("tick rc 0 with findings (fail-closed tick)", 0, r.returncode)
crumb4 = Path(state4, "s.tsv").read_text()
ck("tick crumb is bailiff-halt", 1,
   sum("bailiff-halt" in line for line in crumb4.splitlines()))
ck("tick did not run drop-ins", 0,
   sum("tick-done" in line for line in crumb4.splitlines()))

if FAILS:
    print(f"bailiff contract: {FAILS} FAILURES")
    sys.exit(1)
print("bailiff contract: all cases passed")
