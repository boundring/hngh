"""Executive cadence driver: one beat polls bd for open beads, classifies, emits judgments."""
from __future__ import annotations

import json
import os
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import contract
import state_emitter

try:
    import jev
except ImportError:  # sibling lands in parallel; fail closed per-event
    jev = None  # type: ignore[assignment]

BASE = Path(__file__).resolve().parent
LEDGER = BASE / "ledger"
STATE = LEDGER / "cadence.state.json"
REPO_ROOT = BASE.parents[1]  # bd runs only from a .beads-bearing git root

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


def _open_beads(repo_root: str) -> tuple[list[dict] | None, str]:
    """Poll bd directly — beads are the ledger of record for work."""
    try:
        p = subprocess.run(["bd", "list", "--json", "-n", "0"], cwd=repo_root,
                           capture_output=True, text=True, timeout=60)
        if p.returncode != 0:
            return None, (p.stderr or p.stdout).strip() or f"exit {p.returncode}"
        rows = json.loads(p.stdout)
        if not isinstance(rows, list):
            return None, "not a list"
        return rows, ""
    except (OSError, ValueError, subprocess.SubprocessError) as e:
        return None, f"{type(e).__name__}: {e}"


def _age_days(created_at: str) -> float:
    try:
        dt = datetime.fromisoformat(created_at.replace("Z", "+00:00"))
        return round((datetime.now(timezone.utc) - dt).total_seconds() / 86400, 2)
    except ValueError:
        return 0.0


def _bead_event(row: dict) -> dict:
    """One bd row as a triage event. state_version 0: bd rows carry no
    snapshot version; the stale-version check still guards future
    event-sourced heads."""
    return {"kind": "bead.ready", "state_version": 0,
            "payload": {"id": row.get("id", ""), "title": row.get("title", ""),
                        "status": row.get("status", ""),
                        "age_days": _age_days(row.get("created_at", "")),
                        "tier_hint": row.get("tier_hint", "")}}


def _emit(d: Path, kind: str, payload: dict) -> contract.Event:
    """Single writer: every judgment event goes through state_emitter."""
    return state_emitter.append(kind, payload, ledger_dir=str(d))


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
    """One beat: re-ask deferred beads, then classify open beads fresh
    from the bd poll. Un-asked fresh beads stay due — the next beat's
    poll redisCOVERS them; deferred beads stay eligible via STATE."""
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


def _beat(d: Path, max_events: int, repo_root: str | None = None) -> list:
    emitted: list = []
    date, spent = _budget(d)
    cap = _token_cap()
    deferred = _deferred(d)
    rows, err = _open_beads(repo_root or str(REPO_ROOT))
    if rows is None:
        emitted.append(_emit(d, "state.error", {"error": err}))
        rows = []
    open_ids = {e["event"]["payload"].get("id", "") for e in deferred}
    fresh = [{"event": _bead_event(r), "attempts": 0}
             for r in rows if r.get("id") and r.get("status", "") == "open"
             and r.get("id") not in open_ids]
    queue = [(en, True) for en in deferred] + \
        [(en, False) for en in fresh]
    # Deferred entries beyond the per-bead cap stay parked; fresh beyond
    # it are re-discovered next beat.
    still: list[dict] = [en for en, is_def in queue[max_events:] if is_def]
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
            break  # stop asking for the rest of the beat
        if spent >= cap * _DEGRADE_FRAC and _tier(ev) != "T1":
            # collapse-first degrade: non-T1 stays un-asked; the next
            # beat's bd poll or its deferred entry carries it forward
            if is_deferred:
                still.append(entry)
            continue
        used, park, tok = _handle(d, ev, attempts, emitted)
        spent += tok
        _save_budget(d, date, spent)
        if park:  # triage.deferred lives in STATE now, not as a ledger kind
            still.append({"event": {k: v for k, v in ev.items() if k != "_attempts"},
                          "attempts": used})
    _save_deferred(d, still)
    return emitted

def _dry_run() -> None:
    import tempfile
    from unittest import mock

    def _row(bid, **kw):
        r = {"id": bid, "title": bid, "status": "open", "created_at": ""}
        r.update(kw)
        return r

    def run_case(beads, answers, **kw):
        tmp = tempfile.TemporaryDirectory(prefix="cadence-case-")
        d = Path(tmp.name)
        jev_fx = kw.get("jev_side_effect")
        if "budget" in kw:
            _save_budget(d, _today(), kw["budget"])
        seq = list(answers)
        fake = lambda q: seq.pop(0) if seq else contract.Answer(
            contract.Verdict.ESCALATE, "escalate", (), q.state_version)
        with mock.patch.object(sys.modules[__name__], "_open_beads",
                               return_value=(list(beads), "")), \
                mock.patch.object(jev, "ask", side_effect=jev_fx or fake):
            out = beat(ledger_dir=d, max_events=kw.get("max_events", 16))
        return tmp, d, out

    with tempfile.TemporaryDirectory(prefix="cadence-dry-") as tmp:
        d = Path(tmp)
        q0 = _question({"kind": "bead.ready", "state_version": 1,
                        "payload": {"id": "b-1", "title": "demo", "age_days": 3}})
        assert q0.head == "triage", q0
        assert set(q0.slots) == {"id", "title", "tier_hint", "age_days", "attempts"}, q0.slots
        assert tuple(q0.labels) == LABELS, q0.labels
        tmp, d, out = run_case([_row("b-1", title="demo")],
                               [contract.Answer(contract.Verdict.DONE, "file", (), 0)])
        kinds = [e.kind for e in out]
        assert kinds == ["slice.proposed"], kinds
        print(json.dumps([{"kind": e.kind, "state_version": e.state_version,
                           "payload": dict(e.payload)} for e in out]))

    # Stale verdict (answer bound to a different snapshot) escalates, never acts.
    tmp, d, out = run_case(
        [_row("b-stale")], [contract.Answer(contract.Verdict.DONE, "file", (), 999)])
    assert [e.kind for e in out] == ["escalation.filed"], out
    assert out[0].payload["reason"] == "stale-version", out[0].payload
    tmp.cleanup()

    # Uncertain parks the bead in STATE (no triage.deferred ledger kind);
    # the second beat re-asks with attempts=1 and files on success.
    tmp, d, out = run_case(
        [_row("b-u")], [contract.Answer(contract.Verdict.UNCERTAIN, None, (), 0)])
    assert out == [], out
    assert len(_deferred(d)) == 1 and _deferred(d)[0]["attempts"] == 1, _deferred(d)
    # Second beat: bd poll returns nothing new; b-u comes back via deferred.
    with mock.patch.object(jev, "ask",
                           return_value=contract.Answer(contract.Verdict.DONE, "file", (), 0)), \
            mock.patch.object(sys.modules[__name__], "_open_beads",
                              return_value=([], "")):
        out2 = beat(ledger_dir=d)
    assert [e.kind for e in out2] == ["slice.proposed"], out2
    assert _deferred(d) == [], _deferred(d)
    tmp.cleanup()

    # Attempt cap: retry parks until HNGH_ATTEMPT_CAP, then escalates.
    os.environ["HNGH_ATTEMPT_CAP"] = "2"
    try:
        tmp, d, out = run_case(
            [_row("b-r")], [contract.Answer(contract.Verdict.DONE, "retry", (), 0)])
        assert [e.kind for e in out] == ["slice.retry"], out
        with mock.patch.object(
                jev, "ask",
                return_value=contract.Answer(contract.Verdict.DONE, "retry", (), 0)), \
                mock.patch.object(sys.modules[__name__], "_open_beads",
                                  return_value=([], "")):
            out2 = beat(ledger_dir=d)
        assert [e.kind for e in out2] == ["escalation.filed"], out2
        assert out2[0].payload["reason"] == "attempts-exhausted", out2[0].payload
        assert _deferred(d) == [], _deferred(d)
    finally:
        os.environ.pop("HNGH_ATTEMPT_CAP", None)
    tmp.cleanup()

    # Label map: close -> bead.close; escalate -> escalation.filed.
    tmp, d, out = run_case(
        [_row("b-c"), _row("b-e")],
        [contract.Answer(contract.Verdict.DONE, "close", (), 0),
         contract.Answer(contract.Verdict.ESCALATE, "escalate", (), 0)])
    assert [e.kind for e in out] == ["bead.close", "escalation.filed"], out
    tmp.cleanup()

    # Budget: tiny cap refuses before asking (no ask calls), one escalation.
    os.environ["HNGH_JEV_DAILY_INPUT_TOKEN_CAP"] = "1"
    try:
        tmp, d, out = run_case(
            [_row("b-cap")],
            [contract.Answer(contract.Verdict.ESCALATE, "escalate", (), 0)],
            jev_side_effect=AssertionError("ask must not run"))
        assert [e.kind for e in out] == ["escalation.filed"], out
        assert out[0].payload["reason"] == "budget-exhausted", out[0].payload
        # The skipped fresh bead is not parked; the next beat's poll re-finds it.
        assert _deferred(d) == [], _deferred(d)
        tmp.cleanup()
    finally:
        os.environ.pop("HNGH_JEV_DAILY_INPUT_TOKEN_CAP", None)

    # Degrade: at >=80% only T1 asks; spend persists in STATE.
    os.environ["HNGH_JEV_DAILY_INPUT_TOKEN_CAP"] = "1000"
    try:
        tmp, d, out = run_case(
            [_row("b-t2", tier_hint="T2"), _row("b-t1", tier_hint="T1")],
            [contract.Answer(contract.Verdict.DONE, "file", (), 0, 10)],
            budget=800)
        assert [e.kind for e in out] == ["slice.proposed"], out
        assert out[0].payload["bead"] == "b-t1", out[0].payload
        _, spent = _budget(d)
        assert spent == 810, spent  # 800 + the one T1 ask's 10 tokens
        # The degraded T2 stays un-asked, not parked; next beat re-polls it.
        assert _deferred(d) == [], _deferred(d)
        tmp.cleanup()
    finally:
        os.environ.pop("HNGH_JEV_DAILY_INPUT_TOKEN_CAP", None)
    print("cadence self-check ok")


if __name__ == "__main__":
    if "--dry-run" in sys.argv:
        _dry_run()
    else:
        out = beat()
        print(json.dumps([{"kind": e.kind, "state_version": e.state_version,
                           "payload": dict(e.payload)} for e in out]))
