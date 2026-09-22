#!/usr/bin/env python3
"""test-jcode-spawn-guard — pre-spawn graph guard on launch_jcode_worker
(plan 2026-09-22-federal-branches-occupancy step 2).

Contract: launch-jcode.sh runs automation/ng/jcode_guard.py on
JCODE_PLAN_JSON before spawning the worker; a cap violation (nodes,
depth, cycle) or an unreadable graph file refuses rc 75 with NO worker
spawn (no spend). JCODE_PLAN_JSON unset keeps the wrapper contract
unchanged (guard is additive). Caps honored via HNGH_NODE_CAP /
HNGH_DEPTH_CAP. Hermetic: stub worker, real guard (stdlib), no model.
"""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
LAUNCH = HERE / ".." / "lib" / "launch-jcode.sh"

fails = 0


def ck(desc: str, expected: object, actual: object) -> None:
    global fails
    if expected == actual:
        print(f"ok: {desc}")
    else:
        print(f"FAIL: {desc} (expected={expected!r} actual={actual!r})")
        fails += 1


def run_wrapper(env: dict) -> tuple[int, Path]:
    e = dict(os.environ)
    e.pop("JCODE_PLAN_JSON", None)
    e.update(env)
    r = subprocess.run(
        ["bash", "-c",
         f'. "{LAUNCH}" && launch_jcode_worker'],
        capture_output=True, text=True, env=e,
    )
    return r.returncode, Path(env["JCODE_LOG"])


def node(i: int, deps: list[str]) -> dict:
    return {"id": f"n{i}", "status": "pending", "blocked_by": deps}


def write_json(path: Path, doc: object) -> None:
    path.write_text(doc if isinstance(doc, str) else __import__("json").dumps(doc))


SCRATCH = Path(tempfile.mkdtemp(prefix="hngh-guard-test."))
PROMPT = SCRATCH / "prompt.txt"
PROMPT.write_text("hello guard\n")
STUB = SCRATCH / "stub-worker.mjs"
STUB.write_text(
    'process.stdout.write("stub ran\\n");\n'
    'process.exit(Number(process.env.STUB_RC || 0));\n'
)
BASE = {
    "JCODE_PROMPT_FILE": str(PROMPT),
    "JCODE_WORKER_BIN": str(STUB),
    "AUTOMATION_ROOT": str(HERE / ".."),
}


def case(name: str, plan: object | None, extra: dict) -> tuple[int, Path, str]:
    env = dict(BASE)
    env["JCODE_LOG"] = str(SCRATCH / f"{name}.log")
    if plan is not None:
        p = SCRATCH / f"{name}.json"
        write_json(p, plan)
        env["JCODE_PLAN_JSON"] = str(p)
    env.update(extra)
    rc, log = run_wrapper(env)
    text = log.read_text() if log.exists() else ""
    return rc, log, text


# 1) unset -> additive guard silent, wrapper contract unchanged
rc, _, text = case("unset", None, {})
ck("unset plan json runs", 0, rc)
ck("unset plan json stub output", True, text.startswith("stub ran"))

# 2) small in-bounds graph runs
rc, _, text = case("small", {"items": [node(0, []), node(1, [0])]}, {})
ck("small graph runs", 0, rc)
ck("small graph stub output", True, text.startswith("stub ran"))

# 3) node cap exceeded -> 75, no spawn (no spend)
big = {"items": [node(i, []) for i in range(65)]}
rc, log, text = case("nodecap", big, {})
ck("node cap refuses 75", 75, rc)
ck("node cap no spawn", "", text)

# 4) depth cap exceeded -> 75
chain = {"items": [node(i, [f"n{i-1}"] if i else []) for i in range(9)]}
rc, _, text = case("depth", chain, {})
ck("depth cap refuses 75", 75, rc)
ck("depth cap no spawn", "", text)

# 5) cycle -> unbounded depth -> 75
rc, _, text = case("cycle", {"items": [node(0, ["n1"]), node(1, ["n0"])]}, {})
ck("cycle refuses 75", 75, rc)
ck("cycle no spawn", "", text)

# 6) unreadable graph file -> 75 (fail closed)
env = dict(BASE)
env["JCODE_LOG"] = str(SCRATCH / "bad.log")
env["JCODE_PLAN_JSON"] = str(SCRATCH / "absent.json")
rc, log = run_wrapper(env)
text = log.read_text() if log.exists() else ""
ck("absent plan json refuses 75", 75, rc)
ck("absent plan json no spawn", "", text)

# 7) cap env honored: 3 nodes refuse under HNGH_NODE_CAP=2
three = {"items": [node(i, []) for i in range(3)]}
rc, _, text = case("capenv", three, {"HNGH_NODE_CAP": "2"})
ck("env cap honored refuses 75", 75, rc)
ck("env cap no spawn", "", text)

if fails:
    print(f"jcode-spawn-guard: {fails} FAILURES")
    sys.exit(1)
print("jcode-spawn-guard: all cases passed")
