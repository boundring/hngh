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

# $5/day at ~$0.04 per 1M Jev input tokens -> 125M input tokens/day.
_TOKEN_CAP_DEFAULT = 125_000_000
# Collapse-first degrade: past this fraction of the cap only T1 asks proceed.
_DEGRADE_FRAC = 0.8


def _dir(ledger_dir=None) -> Path:
    return Path(ledger_dir) if ledger_dir else LEDGER


def _token_cap() -> int:
    try:
        return max(1, int(os.environ.get("HNGH_JEV_DAILY_INPUT_TOKEN_CAP",
                                        str(_TOKEN_CAP_DEFAULT))))
    except ValueError:
        return _TOKEN_CAP_DEFAULT


def _today() -> str:
    return time.strftime("%Y-%m-%d", time.gmtime())


def _state(d: Path) -> dict:
    try:
        raw = json.loads((d / STATE.name).read_text())
        return raw if isinstance(raw, dict) else {}
    except (OSError, ValueError, AttributeError):
        return {}


def _write_state(d: Path, st: dict) -> None:
    d.mkdir(parents=True, exist_ok=True)
    (d / STATE.name).write_text(json.dumps(st, default=str))


def _budget(d: Path) -> tuple[str, int]:
    """Daily Jev input-token spend: (UTC date, tokens). Resets each day."""
    today = _today()
    b = _state(d).get("budget", {})
    if isinstance(b, dict) and b.get("date") == today:
        try:
            return today, max(0, int(b.get("input_tokens", 0)))
        except (ValueError, TypeError):
            return today, 0
    return today, 0


def _save_budget(d: Path, date: str, tokens: int) -> None:
    st = _state(d)
    st["budget"] = {"date": date, "input_tokens": tokens}
    _write_state(d, st)


def _project(ev: dict) -> int:
    """Conservative pre-ask token estimate for one event (len//4)."""
    try:
        return max(1, len(json.dumps(ev, default=str).encode("utf-8")) // 4)
    except Exception:
        return 1


def _tier(ev: dict) -> str:
    pay = ev.get("payload", {})
    return str(pay.get("tier_hint", pay.get("tier", "")) or "")


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
    got = _state(d).get("deferred", [])
    return got if isinstance(got, list) else []


def _save_deferred(d: Path, entries: list[dict]) -> None:
    st = _state(d)  # preserve the budget record sharing this file
    st["deferred"] = entries
    _write_state(d, st)

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
    Returns (attempts used, park-for-revisit, input tokens spent).
    NEVER raises — any failure files an escalation (fail closed)."""
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
        return attempts + 1, False, 0
    try:
        tok = max(0, int(getattr(ans, "input_tokens", 0) or 0))
    except (ValueError, TypeError):
        tok = 0
    if getattr(ans, "state_version", ev_sv) != ev_sv:
        emitted.append(_emit(d, "escalation.filed", {"bead": bid, "question_head": "triage",
                                                    "reason": "stale-version"}))
        return attempts + 1, False, tok
    v = _verdict_of(ans)
    label = str(getattr(ans, "label", "") or "").lower()
    done = getattr(contract.Verdict.DONE, "value", "done")
    if v == done and label == "file":
        emitted.append(_emit(d, "slice.proposed", {"bead": bid, "action": ans.label}))
        return attempts + 1, False, tok
    elif v == done and label == "close":
        emitted.append(_emit(d, "bead.close", {"bead": bid}))
        return attempts + 1, False, tok
    elif v == done and label == "retry":
        if attempts + 1 >= cap:  # ponytail: flat cap, per-bead budgets if beads starve
            emitted.append(_emit(d, "escalation.filed", {"bead": bid, "question_head": "triage",
                                                        "reason": "attempts-exhausted"}))
            return attempts + 1, False, tok
        else:
            emitted.append(_emit(d, "slice.retry", {"bead": bid, "attempts": attempts + 1}))
            return attempts + 1, True, tok
    elif "escalate" in (v, label):
        emitted.append(_emit(d, "escalation.filed", {"bead": bid, "question_head": "triage",
                                                    "reason": "jev-escalate"}))
        return attempts + 1, False, tok
    else:  # uncertain / unknown label: park for revisit until the cap, then escalate
        if attempts + 1 >= cap:
            emitted.append(_emit(d, "escalation.filed", {"bead": bid, "question_head": "triage",
                                                        "reason": "attempts-exhausted"}))
            return attempts + 1, False, tok
        return attempts + 1, True, tok


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
    date, spent = _budget(d)
    cap = _token_cap()
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
    rest = queue[:max_events]
    for i, (entry, is_deferred) in enumerate(rest):
        ev, attempts = entry["event"], entry["attempts"]
        bid = ev.get("payload", {}).get("id", "")
        if spent >= cap or spent + _project(ev) > cap:
            emitted.append(_emit(d, "escalation.filed",
                                {"bead": bid, "question_head": "triage",
                                 "reason": "budget-exhausted",
                                 "input_tokens": spent, "cap": cap}))
            for e2, is_def2 in rest[i:]:
                if is_def2:
                    still.append(e2)
                else:
                    still.append({"event": e2["event"], "attempts": e2["attempts"]})
            break  # stop asking for the rest of the beat
        if spent >= cap * _DEGRADE_FRAC and _tier(ev) != "T1":
            # collapse-first degrade: non-T1 parks in STATE (the cursor may
            # advance past it on a later T1, so fresh cannot stay cursor-due)
            still.append(entry if is_deferred else {"event": ev, "attempts": attempts})
            continue
        used, park, tok = _handle(d, ev, attempts, emitted)
        spent += tok
        _save_budget(d, date, spent)
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

    # Budget: tiny cap refuses before asking (no ask calls), one escalation.
    os.environ["HNGH_JEV_DAILY_INPUT_TOKEN_CAP"] = "1"
    try:
        tmp3 = tempfile.TemporaryDirectory(prefix="cadence-case-")
        d3 = Path(tmp3.name)
        _emit(d3, "bead.ready", {"id": "b-cap"})
        with mock.patch.object(jev, "ask",
                               side_effect=AssertionError("ask must not run")):
            out = beat(ledger_dir=d3)
        assert [e.kind for e in out] == ["escalation.filed"], out
        assert out[0].payload["reason"] == "budget-exhausted", out[0].payload
        assert len(_deferred(d3)) == 1 and _deferred(d3)[0]["attempts"] == 0, _deferred(d3)
        tmp3.cleanup()
    finally:
        os.environ.pop("HNGH_JEV_DAILY_INPUT_TOKEN_CAP", None)

    # Degrade: at >=80% only T1 asks; spend persists in STATE.
    os.environ["HNGH_JEV_DAILY_INPUT_TOKEN_CAP"] = "1000"
    try:
        tmp4 = tempfile.TemporaryDirectory(prefix="cadence-case-")
        d4 = Path(tmp4.name)
        _save_budget(d4, _today(), 800)
        _emit(d4, "bead.ready", {"id": "b-t2", "tier_hint": "T2"})
        _emit(d4, "bead.ready", {"id": "b-t1", "tier_hint": "T1"})
        seq = [contract.Answer(contract.Verdict.DONE, "file", (), 2, 10)]
        with mock.patch.object(jev, "ask", side_effect=lambda q: seq.pop(0)):
            out = beat(ledger_dir=d4)
        assert [e.kind for e in out] == ["slice.proposed"], out
        assert out[0].payload["bead"] == "b-t1", out[0].payload
        _, spent = _budget(d4)
        assert spent == 810, spent  # 800 + the one T1 ask's 10 tokens
        assert len(_deferred(d4)) == 1 and _deferred(d4)[0]["event"]["payload"]["id"] == "b-t2", _deferred(d4)
        assert _cursor(d4) == 2, _cursor(d4)  # T1 at sv2 done; skipped T2 (sv1) re-read next beat
        tmp4.cleanup()
    finally:
        os.environ.pop("HNGH_JEV_DAILY_INPUT_TOKEN_CAP", None)
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
