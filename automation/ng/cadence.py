"""Executive cadence driver: one beat classifies bead.ready, emits decisions."""
from __future__ import annotations

import json
import os
import sys
import time
from pathlib import Path

import contract

try:
    import jev
except ImportError:  # sibling lands in parallel; fail closed per-event
    jev = None  # type: ignore[assignment]

BASE = Path(__file__).resolve().parent
LEDGER = BASE / "ledger"
EVENTS = LEDGER / "events.jsonl"
VERSION = LEDGER / "version"
CURSOR = LEDGER / "cadence.cursor.json"
STATE = LEDGER / "cadence.state.json"

LABELS = ("file", "retry", "escalate", "close")


def _dir(ledger_dir=None) -> Path:
    return Path(ledger_dir) if ledger_dir else LEDGER


def _attempt_cap() -> int:
    try:
        return max(1, int(os.environ.get("HNGH_ATTEMPT_CAP", "3")))
    except ValueError:
        return 3


def _version(d: Path) -> int:
    try:
        return int((d / "version").read_text().strip())
    except (OSError, ValueError):
        return 0


def _emit(d: Path, kind: str, payload: dict) -> contract.Event:
    d.mkdir(parents=True, exist_ok=True)
    ver = _version(d) + 1
    (d / "version").write_text(str(ver))
    evt = {"kind": kind, "state_version": ver, "payload": payload,
           "created_at": time.time(), "refs": []}
    with open(d / "events.jsonl", "a") as f:
        f.write(json.dumps(evt) + "\n")
    return contract.Event(kind=kind, state_version=ver, payload=payload)


def _events(d: Path) -> list[dict]:
    try:
        lines = open(d / "events.jsonl").read().splitlines()
    except OSError:
        return []
    out = []
    for ln in lines:
        try:
            out.append(json.loads(ln))
        except ValueError:
            continue
    return out


def _cursor(d: Path) -> int:
    try:
        return int(json.loads((d / CURSOR.name).read_text()).get("last_version", 0))
    except (OSError, ValueError, AttributeError):
        return 0


def _save_cursor(d: Path, ver: int) -> None:
    (d / CURSOR.name).write_text(json.dumps({"last_version": ver}))


def _deferred(d: Path) -> list[dict]:
    """Parked triage entries still due: [{event, attempts}]."""
    try:
        raw = json.loads((d / STATE.name).read_text())
        return raw.get("deferred", []) if isinstance(raw, dict) else []
    except (OSError, ValueError, AttributeError):
        return []


def _save_deferred(d: Path, entries: list[dict]) -> None:
    (d / STATE.name).write_text(json.dumps({"deferred": entries}, default=str))

def _question(ev: dict) -> "contract.Question":
    pay = ev.get("payload", {})
    attempts = ev.get("_attempts", pay.get("attempts", 0))
    return contract.Question(
        head="triage",
        slots={"id": pay.get("id", ""), "title": pay.get("title", ""),
               "tier_hint": pay.get("tier_hint", pay.get("tier", "")),
               "age_days": pay.get("age_days", 0),
               "attempts": attempts},
        labels=LABELS, state_version=ev.get("state_version", 0))


def _verdict_of(ans) -> str:
    v = getattr(ans, "verdict", None)
    return str(getattr(v, "value", v))


def _handle(d: Path, ev: dict, attempts: int, emitted: list) -> tuple[int, bool]:
    """Ask Jev for one event, emit the mapped action.
    Returns (attempts used, park-for-revisit). NEVER raises — any failure
    files an escalation (fail closed)."""
    bid = ev.get("payload", {}).get("id", "")
    ev_sv = ev.get("state_version", 0)
    cap = _attempt_cap()
    try:
        if jev is None:
            raise RuntimeError("jev unavailable")
        ev["_attempts"] = attempts
        ans = jev.ask(_question(ev))
    except Exception:
        emitted.append(_emit(d, "escalation.filed", {"bead": bid, "question_head": "triage",
                                                    "reason": "jev-error"}))
        return attempts + 1, False
    if getattr(ans, "state_version", ev_sv) != ev_sv:
        emitted.append(_emit(d, "escalation.filed", {"bead": bid, "question_head": "triage",
                                                    "reason": "stale-version"}))
        return attempts + 1, False
    v = _verdict_of(ans)
    label = str(getattr(ans, "label", "") or "").lower()
    done = getattr(contract.Verdict.DONE, "value", "done")
    if v == done and label == "file":
        emitted.append(_emit(d, "slice.proposed", {"bead": bid, "action": ans.label}))
        return attempts + 1, False
    elif v == done and label == "close":
        emitted.append(_emit(d, "bead.close", {"bead": bid}))
        return attempts + 1, False
    elif v == done and label == "retry":
        if attempts + 1 >= cap:  # ponytail: flat cap, per-bead budgets if beads starve
            emitted.append(_emit(d, "escalation.filed", {"bead": bid, "question_head": "triage",
                                                        "reason": "attempts-exhausted"}))
            return attempts + 1, False
        else:
            emitted.append(_emit(d, "slice.retry", {"bead": bid, "attempts": attempts + 1}))
            return attempts + 1, True
    elif "escalate" in (v, label):
        emitted.append(_emit(d, "escalation.filed", {"bead": bid, "question_head": "triage",
                                                    "reason": "jev-escalate"}))
        return attempts + 1, False
    else:  # uncertain / unknown label: park for revisit until the cap, then escalate
        if attempts + 1 >= cap:
            emitted.append(_emit(d, "escalation.filed", {"bead": bid, "question_head": "triage",
                                                        "reason": "attempts-exhausted"}))
            return attempts + 1, False
        return attempts + 1, True


def beat(ledger_dir=None, base_url=None, max_events: int = 16) -> list:
    """One beat: re-ask deferred beads, then classify new bead.ready events.
    Cursor advances per event; deferred beads stay eligible via STATE."""
    d = _dir(ledger_dir)
    old_url = os.environ.get("HNGH_JEV_URL")
    if base_url is not None:
        os.environ["HNGH_JEV_URL"] = base_url
    try:
        return _beat(d, max_events)
    finally:
        if base_url is not None:
            if old_url is None:
                os.environ.pop("HNGH_JEV_URL", None)
            else:
                os.environ["HNGH_JEV_URL"] = old_url


def _beat(d: Path, max_events: int) -> list:
    emitted: list = []
    cur = _cursor(d)
    deferred = _deferred(d)
    fresh = sorted((e for e in _events(d)
                    if e.get("kind") == "bead.ready"
                    and (e.get("state_version", 0) or 0) > cur),
                   key=lambda e: e.get("state_version", 0))
    queue = [(en, True) for en in deferred] + \
        [({"event": e, "attempts": 0}, False) for e in fresh]
    # Deferred entries past the cap stay parked; fresh past the cap stay
    # due via the cursor and are picked up next beat.
    still: list[dict] = [entry for entry, is_def in queue[max_events:] if is_def]
    for entry, is_deferred in queue[:max_events]:
        ev, attempts = entry["event"], entry["attempts"]
        used, park = _handle(d, ev, attempts, emitted)
        if not is_deferred:
            _save_cursor(d, max(ev.get("state_version", cur) or cur, _cursor(d)))
        if park:  # triage.deferred lives in STATE now, not as a ledger kind
            still.append({"event": {k: v for k, v in ev.items() if k != "_attempts"},
                          "attempts": used})
    _save_deferred(d, still)
    return emitted

def _dry_run() -> None:
    import tempfile
    from unittest import mock

    def run_case(beads, answers, **kw):
        tmp = tempfile.TemporaryDirectory(prefix="cadence-case-")
        d = Path(tmp.name)
        for b in beads:
            _emit(d, "bead.ready", b)
        sv = _version(d)
        seq = list(answers)
        fake = lambda q: seq.pop(0) if seq else contract.Answer(
            contract.Verdict.ESCALATE, "escalate", (), q.state_version)
        with mock.patch.object(jev, "ask", side_effect=fake) if jev else _null_ctx():
            out = beat(ledger_dir=d, max_events=kw.get("max_events", 16))
        return tmp, d, out, sv

    with tempfile.TemporaryDirectory(prefix="cadence-dry-") as tmp:
        d = Path(tmp)
        _emit(d, "bead.ready", {"id": "b-1", "title": "demo", "age_days": 3})
        q0 = _question({"kind": "bead.ready", "state_version": 1,
                        "payload": {"id": "b-1", "title": "demo", "age_days": 3}})
        assert q0.head == "triage", q0
        assert set(q0.slots) == {"id", "title", "tier_hint", "age_days", "attempts"}, q0.slots
        assert tuple(q0.labels) == LABELS, q0.labels
        stub = contract.Answer(contract.Verdict.DONE, "file", (), 1)
        with mock.patch.object(jev, "ask", return_value=stub) if jev else _null_ctx():
            out = beat(ledger_dir=d)
        kinds = [e.kind for e in out]
        assert kinds == ["slice.proposed"], kinds
        assert _cursor(d) == 1, _cursor(d)
        print(json.dumps([{"kind": e.kind, "state_version": e.state_version,
                           "payload": dict(e.payload)} for e in out]))

    # Stale verdict (answer bound to a different snapshot) escalates, never acts.
    tmp, d, out, _ = run_case(
        [{"id": "b-stale"}], [contract.Answer(contract.Verdict.DONE, "file", (), 999)])
    assert [e.kind for e in out] == ["escalation.filed"], out
    assert out[0].payload["reason"] == "stale-version", out[0].payload
    tmp.cleanup()

    # Uncertain parks the bead in STATE (no triage.deferred ledger kind);
    # the second beat re-asks with attempts=1 and files on success.
    tmp, d, out, _ = run_case(
        [{"id": "b-u"}], [contract.Answer(contract.Verdict.UNCERTAIN, None, (), 1)])
    assert out == [], out
    assert len(_deferred(d)) == 1 and _deferred(d)[0]["attempts"] == 1, _deferred(d)
    assert _cursor(d) == 1, _cursor(d)  # per-event cursor advanced past b-u
    with mock.patch.object(jev, "ask",
                            return_value=contract.Answer(contract.Verdict.DONE, "file", (), 1)):
        out2 = beat(ledger_dir=d)
    assert [e.kind for e in out2] == ["slice.proposed"], out2
    assert _deferred(d) == [], _deferred(d)
    tmp.cleanup()

    # Attempt cap: retry parks until HNGH_ATTEMPT_CAP, then escalates.
    os.environ["HNGH_ATTEMPT_CAP"] = "2"
    try:
        tmp, d, out, _ = run_case(
            [{"id": "b-r"}], [contract.Answer(contract.Verdict.DONE, "retry", (), 1)])
        assert [e.kind for e in out] == ["slice.retry"], out
        with mock.patch.object(
                jev, "ask",
                return_value=contract.Answer(contract.Verdict.DONE, "retry", (), 1)):
            out2 = beat(ledger_dir=d)
        assert [e.kind for e in out2] == ["escalation.filed"], out2
        assert out2[0].payload["reason"] == "attempts-exhausted", out2[0].payload
        assert _deferred(d) == [], _deferred(d)
    finally:
        os.environ.pop("HNGH_ATTEMPT_CAP", None)
    tmp.cleanup()

    # Label map: close -> bead.close; escalate -> escalation.filed.
    tmp2 = tempfile.TemporaryDirectory(prefix="cadence-case-")
    d2 = Path(tmp2.name)
    _emit(d2, "bead.ready", {"id": "b-c"})
    _emit(d2, "bead.ready", {"id": "b-e"})
    v1 = _version(d2) - 1  # b-c's snapshot; b-e is at _version(d2)
    seq = [contract.Answer(contract.Verdict.DONE, "close", (), v1),
           contract.Answer(contract.Verdict.ESCALATE, "escalate", (), _version(d2))]
    with mock.patch.object(jev, "ask", side_effect=lambda q: seq.pop(0)):
        out = beat(ledger_dir=d2)
    assert [e.kind for e in out] == ["bead.close", "escalation.filed"], out
    assert _cursor(d2) == v1 + 1, (_cursor(d2), v1)  # cursor rests on last bead.ready
    tmp2.cleanup()
    print("cadence self-check ok")


class _null_ctx:
    def __enter__(self): return None
    def __exit__(self, *a): return False


if __name__ == "__main__":
    if "--dry-run" in sys.argv:
        _dry_run()
    else:
        out = beat()
        print(json.dumps([{"kind": e.kind, "state_version": e.state_version,
                           "payload": dict(e.payload)} for e in out]))
