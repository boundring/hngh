"""Self-test for jcode_guard: stdlib only, inline fixtures, no ~/.jcode reads."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile

GUARD = os.path.join(os.path.dirname(os.path.abspath(__file__)), "jcode_guard.py")


def run(doc: str | None, fname: str = "s.json", env_cap: str | None = None) -> subprocess.CompletedProcess:
    env = dict(os.environ)
    if env_cap is not None:
        env["HNGH_NODE_CAP"] = env_cap
    with tempfile.TemporaryDirectory() as td:
        path = os.path.join(td, fname)
        if doc is not None:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(doc)
        return subprocess.run([sys.executable, GUARD, path], capture_output=True, text=True, env=env)


def ok_small() -> None:
    doc = json.dumps({"plan": {"items": [
        {"id": "a", "status": "completed"},
        {"id": "b", "status": "queued", "blocked_by": ["a"]},
    ]}})
    r = run(doc)
    assert r.returncode == 0, r.stderr
    assert "ok:" in r.stderr and "completed=1" in r.stderr and "queued=1" in r.stderr, r.stderr


def cap_violation() -> None:
    items = [{"id": f"n{i}", "status": "queued"} for i in range(5)]
    r = run(json.dumps({"plan": {"items": items}}), env_cap="4")
    assert r.returncode == 1, r.stderr
    assert r.stderr.count("\n") == 1 and "node-cap" in r.stderr, r.stderr


def malformed() -> None:
    r = run("{not json")
    assert r.returncode == 1, r.stderr
    assert r.stderr.count("\n") == 1 and "unreadable" in r.stderr, r.stderr


def missing_file() -> None:
    r = run(None, fname="nope.json")
    assert r.returncode == 1 and "unreadable" in r.stderr, r.stderr


if __name__ == "__main__":
    for fn in (ok_small, cap_violation, malformed, missing_file):
        fn()
        print(f"PASS {fn.__name__}")
    print("jcode_guard self-test: all pass")
