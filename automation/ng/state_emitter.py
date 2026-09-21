"""Judgment-event ledger API — the single writer for events.jsonl.

Beads (bd/Dolt) are the ledger of record for work; this module records
only judgment events (verdicts, escalations, budget spend, errors) that
beads cannot hold. One writer bumps the ledger version — cadence and
watch both go through append(), never their own bump. Stdlib only.
"""
from __future__ import annotations

import json
import time
from pathlib import Path

import contract

HERE = Path(__file__).resolve().parent
LEDGER = HERE / "ledger"
EVENTS = LEDGER / "events.jsonl"
VERSION = LEDGER / "version"


def _dir(ledger_dir=None) -> Path:
    return Path(ledger_dir) if ledger_dir else LEDGER


def _version(d: Path) -> int:
    try:
        return int((d / VERSION.name).read_text().strip() or "0")
    except (OSError, ValueError):
        return 0


def append(kind: str, payload: dict, refs: list[str] | None = None,
           ledger_dir=None) -> contract.Event:
    """Append one judgment event and bump the ledger version."""
    d = _dir(ledger_dir)
    d.mkdir(parents=True, exist_ok=True)
    v = _version(d) + 1
    (d / VERSION.name).write_text(f"{v}\n")
    ev = contract.Event(kind, v, payload, time.time(), tuple(refs or ()))
    with open(d / EVENTS.name, "a") as f:
        f.write(json.dumps({"kind": ev.kind, "state_version": ev.state_version,
                            "payload": ev.payload, "created_at": ev.created_at,
                            "refs": list(ev.refs)}) + "\n")
    return ev


def read_events(n: int = 200, ledger_dir=None) -> list[contract.Event]:
    d = _dir(ledger_dir)
    try:
        lines = (d / EVENTS.name).read_text().splitlines()[-n:]
    except OSError:
        return []
    out = []
    for line in lines:
        try:
            row = json.loads(line)
            out.append(contract.Event(row["kind"], row["state_version"],
                                      row.get("payload", {}),
                                      row.get("created_at", 0.0),
                                      tuple(row.get("refs", []))))
        except (ValueError, KeyError):
            continue
    return out


class StateEmitter(contract.Kernel):
    name = "state"

    def observe(self, ledger: object = None) -> list[contract.Event]:
        return read_events()

    def judge(self, question: contract.Question) -> contract.Answer:
        return contract.Answer(contract.Verdict.DONE, None, (), question.state_version)

    def act(self, event: contract.Event) -> None:
        append(event.kind, dict(event.payload), list(event.refs))


if __name__ == "__main__":
    import tempfile
    with tempfile.TemporaryDirectory(prefix="emitter-dry-") as tmp:
        v0 = _version(Path(tmp))
        append("audit.test", {"x": 1}, ledger_dir=tmp)
        append("audit.test", {"x": 2}, ledger_dir=tmp)
        v2 = _version(Path(tmp))
        evs = read_events(ledger_dir=tmp)
    print(f"version {v0} -> {v2}")
    assert v2 == v0 + 2, (v0, v2)
    assert [e.payload.get("x") for e in evs] == [1, 2], evs
    print("state_emitter self-check ok")