"""Watch kernel — audits the ledger, never alerts. Stdlib only."""
from __future__ import annotations

import json
import os
import sys
import time
from collections import Counter
from pathlib import Path

import contract

HERE = Path(__file__).resolve().parent
# Hermetic seam (bailiff contract, 2026-09-22): HNGH_LEDGER_DIR redirects
# the whole ledger surface; unset keeps the in-repo default.
LEDGER = Path(os.environ.get("HNGH_LEDGER_DIR") or HERE / "ledger")
EVENTS = LEDGER / "events.jsonl"
VERSION = LEDGER / "version"
CURSOR = LEDGER / "watch_cursor.json"

STALE_THRESHOLD = 50
BURST_LIMIT = 100


class Watch(contract.Kernel):
    name = "watch"

    def observe(self, ledger: object = None) -> list[contract.Event]:
        return observe(EVENTS)

    def judge(self, question: contract.Question) -> contract.Answer:
        findings = audit()
        label = "findings" if findings else "clean"
        return contract.Answer(contract.Verdict.DONE, label,
                               tuple(f.state_version for f in findings),
                               question.state_version)

    def act(self, event: contract.Event) -> None:
        append(event.kind, dict(event.payload), list(event.refs))


def _vnum(v: str) -> int:
    try:
        return int(str(v).lstrip("v"))
    except ValueError:
        return 0


def _current() -> int:
    try:
        return int(VERSION.read_text().strip() or "0")
    except (OSError, ValueError):
        return 0


def _bump() -> str:
    LEDGER.mkdir(parents=True, exist_ok=True)
    v = _current() + 1
    VERSION.write_text(f"{v}\n")
    return f"v{v:08d}"


def append(kind: str, payload: dict, refs: list[str] | None = None) -> contract.Event:
    ev = contract.Event(kind, _bump(), payload, time.time(), tuple(refs or ()))
    with open(EVENTS, "a") as f:
        f.write(json.dumps({"kind": ev.kind, "state_version": ev.state_version,
                             "payload": ev.payload, "created_at": ev.created_at,
                             "refs": list(ev.refs)}) + "\n")
    return ev


def observe(ledger_path: object = EVENTS, n: int = 200) -> list[contract.Event]:
    try:
        lines = Path(str(ledger_path)).read_text().splitlines()[-n:]
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


def stale_verdict(ev: contract.Event, current: int = 0, threshold: int = STALE_THRESHOLD,
                  ) -> contract.Event | None:
    if current - _vnum(ev.state_version) > threshold:
        return contract.Event("audit.finding", f"v{current:08d}",
                              {"check": "stale_verdict", "kind": ev.kind,
                               "event_version": ev.state_version,
                               "current_version": f"v{current:08d}"},
                              time.time(), ev.refs)
    return None


def unread_burst(counts: Counter, limit: int = BURST_LIMIT,
                 current: int = 0) -> contract.Event | None:
    for kind, count in counts.most_common(1):
        if count > limit:
            return contract.Event("audit.finding", f"v{current:08d}",
                                  {"check": "unread_burst", "kind": kind, "count": count},
                                  time.time(), ())
    return None


CHECKS = ("stale_verdict", "unread_burst")


def audit(events: list[contract.Event] | None = None, threshold: int = STALE_THRESHOLD,
          limit: int = BURST_LIMIT) -> list[contract.Event]:
    events = observe() if events is None else events
    current = _vnum(events[-1].state_version) if events else _current()
    current = max(current, _current())
    try:
        prev = json.loads(CURSOR.read_text()).get("kinds", {}) if CURSOR.exists() else {}
    except (OSError, ValueError):
        prev = {}
    # ponytail: cursor holds per-kind totals at last audit; burst = growth since then.
    counts: Counter = Counter(ev.kind for ev in events if ev.kind != "audit.finding")
    new = Counter({k: c - int(prev.get(k, 0)) for k, c in counts.items()})
    new = Counter({k: c for k, c in new.items() if c > 0})
    findings = [f for ev in events if (f := stale_verdict(ev, current, threshold))]
    if (burst := unread_burst(new, limit, current)):
        findings.append(burst)
    LEDGER.mkdir(parents=True, exist_ok=True)
    CURSOR.write_text(json.dumps({"kinds": dict(counts),
                                  "version": f"v{current:08d}"}))
    return findings


if __name__ == "__main__" and len(sys.argv) > 1 and sys.argv[1] == "--bailiff":
    # Bailiff CLI (read-only audit; never writes). stdout carries the
    # verdict line the bash gate greps; stderr carries finding detail.
    fs = audit()
    for f in fs:
        print(f"finding {f.payload.get('check')} {f.state_version}",
              file=sys.stderr)
    print("bailiff: halt" if fs else "bailiff: clean")
    sys.exit(1 if fs else 0)

if __name__ == "__main__":
    evs = [contract.Event("bead.ready", "v00000001", {"id": "b1"}, 1.0, ("b1",)),
           contract.Event("bead.ready", "v00000100", {"id": "b2"}, 2.0, ("b2",)),
           contract.Event("bead.changed", "v00000100", {"id": "b2"}, 3.0, ("b2",))]
    # current=100, threshold=50: only the v1 event is stale; per-kind counts < burst limit.
    found = audit(evs, threshold=50, limit=100)
    assert len(found) == 1 and found[0].kind == "audit.finding", found
    assert found[0].payload == {"check": "stale_verdict", "kind": "bead.ready",
                                "event_version": "v00000001",
                                "current_version": "v00000100"}, found[0].payload
    print("watch self-check: 1 finding as expected")
