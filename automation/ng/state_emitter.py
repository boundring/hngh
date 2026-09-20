"""State emitter kernel — bead deltas -> ledger events. Stdlib only."""
from __future__ import annotations

import json
import subprocess
import time
from datetime import datetime, timezone
from pathlib import Path

import contract

HERE = Path(__file__).resolve().parent
LEDGER = HERE / "ledger"
EVENTS = LEDGER / "events.jsonl"
VERSION = LEDGER / "version"
LAST_STATE = LEDGER / "last_state.json"


class StateEmitter(contract.Kernel):
    name = "state"

    def observe(self, ledger: object = None) -> list[contract.Event]:
        return read_events()

    def judge(self, question: contract.Question) -> contract.Answer:
        return contract.Answer(contract.Verdict.DONE, None, (), question.state_version)

    def act(self, event: contract.Event) -> None:
        append(event.kind, dict(event.payload), list(event.refs))


def _version() -> int:
    try:
        return int(VERSION.read_text().strip() or "0")
    except (OSError, ValueError):
        return 0


def _bump() -> str:
    LEDGER.mkdir(parents=True, exist_ok=True)
    v = _version() + 1
    VERSION.write_text(f"{v}\n")
    return f"v{v:08d}"


def append(kind: str, payload: dict, refs: list[str] | None = None) -> contract.Event:
    ev = contract.Event(kind, _bump(), payload, time.time(), tuple(refs or ()))
    with open(EVENTS, "a") as f:
        f.write(json.dumps({"kind": ev.kind, "state_version": ev.state_version,
                             "payload": ev.payload, "created_at": ev.created_at,
                             "refs": list(ev.refs)}) + "\n")
    return ev


def read_events(n: int = 200) -> list[contract.Event]:
    try:
        lines = EVENTS.read_text().splitlines()[-n:]
    except OSError:
        return []
    out = []
    for line in lines:
        try:
            d = json.loads(line)
            out.append(contract.Event(d["kind"], d["state_version"], d.get("payload", {}),
                                      d.get("created_at", 0.0), tuple(d.get("refs", []))))
        except (ValueError, KeyError):
            continue
    return out


def _age_days(created_at: str) -> float:
    try:
        dt = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
        return round((datetime.now(timezone.utc) - dt).total_seconds() / 86400, 2)
    except ValueError:
        return 0.0


def _load_beads(repo_root: str) -> tuple[list[dict] | None, str]:
    try:
        p = subprocess.run(["bd", "list", "--json", "-n", "0"], cwd=repo_root,
                           capture_output=True, text=True, timeout=60)
        if p.returncode != 0:
            return None, (p.stderr or p.stdout).strip() or f"exit {p.returncode}"
        rows = json.loads(p.stdout)
        return rows if isinstance(rows, list) else None, "not a list"
    except (OSError, ValueError, subprocess.SubprocessError) as e:
        return None, f"{type(e).__name__}: {e}"


def _snap(row: dict) -> dict:
    return {"id": row.get("id"), "title": row.get("title", ""),
            "status": row.get("status", ""), "age_days": _age_days(row.get("created_at", ""))}


def emit_new_events(repo_root: str, force: bool = False) -> list[contract.Event]:
    rows, err = _load_beads(repo_root)
    if rows is None:
        return [append("state.error", {"error": err})]
    try:
        last = json.loads(LAST_STATE.read_text()) if LAST_STATE.exists() else {}
    except (OSError, ValueError):
        last = {}
    if force:
        last = {}
    out, cur = [], dict(last)
    for row in rows:
        bid = row.get("id")
        if not bid:
            continue
        s = _snap(row)
        prev = last.get(bid)
        if prev is None:
            out.append(append("bead.ready", s, [bid]))
        elif prev.get("title") != s["title"] or prev.get("status") != s["status"]:
            out.append(append("bead.changed", s, [bid]))
        cur[bid] = s
    LEDGER.mkdir(parents=True, exist_ok=True)
    LAST_STATE.write_text(json.dumps(cur, indent=1))
    return out


if __name__ == "__main__":
    root = str(Path(__file__).resolve().parents[2])
    v0 = _version()
    # ponytail: force resync on self-check so the strict-increase assert holds
    # on a quiescent repo; normal runs pass force=False and emit deltas only.
    emit_new_events(root, force=True)
    v1 = _version()
    emit_new_events(root, force=True)
    v2 = _version()
    print(f"version {v0} -> {v1} -> {v2}")
    assert v1 > v0 and v2 > v1, "version file must strictly increase across forced runs"
