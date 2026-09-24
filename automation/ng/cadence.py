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
import tiering

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


# Dispatch ceiling (charter step 4): max dispatch-classified actions
# (slice.proposed, the work-dispatch verb) per UTC day from this beat.
_DISPATCH_CAP_DEFAULT = 4  # mirrors the legacy agent-respawn default
_PARAMS = BASE.parent / "cadence-params.tsv"


def _param(key: str) -> str | None:
    """Value for `key` in the Inventory tsv, or None (4 cols, tab-separated)."""
    try:
        for line in _PARAMS.read_text().splitlines():
            cols = line.split("\t")
            if len(cols) >= 2 and cols[0].strip() == key:
                return cols[1].strip()
    except OSError:
        pass
    return None


def _dispatch_cap() -> int:
    raw = os.environ.get("HNGH_DISPATCH_DAY_CAP") or _param("dispatch-day-max")
    try:
        return max(0, int(str(raw)))
    except (TypeError, ValueError):
        return _DISPATCH_CAP_DEFAULT


def _dispatch_admit(d: Path) -> bool:
    """One UTC-day counter in STATE. True + increments when under cap."""
    today = _today()
    st = _state(d)
    row = st.get("dispatch", {})
    count = 0
    if isinstance(row, dict) and row.get("date") == today:
        try:
            count = max(0, int(row.get("count", 0)))
        except (ValueError, TypeError):
            count = 0
    if count >= _dispatch_cap():
        return False
    st["dispatch"] = {"date": today, "count": count + 1}
    _write_state(d, st)
    return True


def _legs() -> list[dict] | None:
    """Jev legs from HNGH_JEV_LEGS ("kind=url,kind=url"); None = unconfigured."""
    raw = os.environ.get("HNGH_JEV_LEGS", "")
    if not raw:
        return None
    legs: list[dict] = []
    for part in raw.split(","):
        kind, _, url = part.partition("=")
        kind = kind.strip().lower() or "cash"
        url = url.strip()
        legs.append({"kind": kind, "prepaid": kind == "prepaid",
                     "url": url, "blocked": not url})
    return legs


def _leg_url() -> tuple[str | None, bool]:
    """(base_url, legs_configured). url None + configured = all legs blocked."""
    legs = _legs()
    if legs is None:
        return None, False
    for leg in tiering.leg_order(legs):
        if not leg.get("blocked"):
            return leg["url"] or None, True
    return None, True


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


def _exhausted(d: Path) -> list[str]:
    """Beads that hit the attempt cap: dropped from the loop until they
    leave bd's open set (halt condition for the escalation lanes)."""
    got = _state(d).get("exhausted", [])
    return got if isinstance(got, list) else []

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


def _handle(d: Path, ev: dict, attempts: int, emitted: list, ans,
            is_def: bool = False, exhausted: set | None = None
            ) -> tuple[int, bool, int, bool]:
    """Consume one injected Jev answer, emit the mapped action.
    Returns (attempts used, park-for-revisit, input tokens, stop-beat).
    NEVER raises — any failure files an escalation (fail closed)."""
    bid = ev.get("payload", {}).get("id", "")
    ev_sv = ev.get("state_version", 0)
    cap = _attempt_cap()
    if ans is None:  # ask plumbing failed (jev missing or raised); a soft
        # jev failure arrives as its ESCALATE-on-failure Answer shape below
        emitted.append(_emit(d, "escalation.filed", {"bead": bid, "question_head": "triage",
                                                    "reason": "jev-error"}))
        return attempts + 1, False, 0, False
    try:
        tok = max(0, int(getattr(ans, "input_tokens", 0) or 0))
    except (ValueError, TypeError):
        tok = 0
    if getattr(ans, "state_version", ev_sv) != ev_sv:
        emitted.append(_emit(d, "escalation.filed", {"bead": bid, "question_head": "triage",
                                                    "reason": "stale-version"}))
        if attempts + 1 >= cap:  # cap persistent misbinding before it loops spend
            emitted.append(_emit(d, "escalation.filed", {"bead": bid, "question_head": "triage",
                                                        "reason": "attempts-exhausted"}))
            if exhausted is not None:
                exhausted.add(bid)
            return attempts + 1, False, tok, False
        return attempts + 1, True, tok, False
    v = _verdict_of(ans)
    label = str(getattr(ans, "label", "") or "").lower()
    done = getattr(contract.Verdict.DONE, "value", "done")
    if v == done and label == "file":
        if not _dispatch_admit(d):
            # Dispatch ceiling: refuse + defer to the next beat (charter step 4).
            emitted.append(_emit(d, "escalation.filed", {"bead": bid, "question_head": "triage",
                                                        "reason": "dispatch-capped"}))
            return attempts + 1, is_def, tok, True
        emitted.append(_emit(d, "slice.proposed", {"bead": bid, "action": ans.label}))
        return attempts + 1, False, tok, False
    elif v == done and label == "close":
        emitted.append(_emit(d, "bead.close", {"bead": bid}))
        return attempts + 1, False, tok, False
    elif v == done and label == "retry":
        if attempts + 1 >= cap:  # ponytail: flat cap, per-bead budgets if beads starve
            emitted.append(_emit(d, "escalation.filed", {"bead": bid, "question_head": "triage",
                                                        "reason": "attempts-exhausted"}))
            if exhausted is not None:
                exhausted.add(bid)
            return attempts + 1, False, tok, False
        else:
            emitted.append(_emit(d, "slice.retry", {"bead": bid, "attempts": attempts + 1}))
            return attempts + 1, True, tok, False
    elif "escalate" in (v, label):
        if attempts + 1 >= cap:
            emitted.append(_emit(d, "escalation.filed", {"bead": bid, "question_head": "triage",
                                                        "reason": "attempts-exhausted"}))
            if exhausted is not None:
                exhausted.add(bid)
            return attempts + 1, False, tok, False
        # Park: attempts must accumulate through STATE, or a Jev "escalate"
        # re-fires fresh every beat forever (no halt condition).
        emitted.append(_emit(d, "escalation.filed", {"bead": bid, "question_head": "triage",
                                                    "reason": "jev-escalate"}))
        return attempts + 1, True, tok, False
    else:  # uncertain / unknown label: park for revisit until the cap, then escalate
        if attempts + 1 >= cap:
            emitted.append(_emit(d, "escalation.filed", {"bead": bid, "question_head": "triage",
                                                        "reason": "attempts-exhausted"}))
            if exhausted is not None:
                exhausted.add(bid)
            return attempts + 1, False, tok, False
        return attempts + 1, True, tok, False


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
    exhausted = set(_exhausted(d))
    if rows is not None:  # purge only on a healthy poll — never wipe on bd fault
        exhausted &= {r.get("id", "") for r in rows}
    open_ids = {e["event"]["payload"].get("id", "") for e in deferred}
    open_ids |= exhausted
    fresh = [{"event": _bead_event(r), "attempts": 0}
             for r in rows if r.get("id") and r.get("status", "") == "open"
             and r.get("id") not in open_ids]
    queue = [(en, True) for en in deferred
             if en["event"]["payload"].get("id", "") not in exhausted] + \
        [(en, False) for en in fresh]
    # Deferred entries beyond the per-bead cap stay parked; fresh beyond
    # it are re-discovered next beat.
    still: list[dict] = [en for en, is_def in queue[max_events:] if is_def]
    rest = queue[:max_events]
    leg_url, legs_on = _leg_url()
    if legs_on and leg_url is None:
        # All configured legs blocked: re-route to the next window, never stall.
        emitted.append(_emit(d, "escalation.filed", {"bead": "", "question_head": "triage",
                                                    "reason": "legs-exhausted"}))
        _save_deferred(d, [en for en, is_def in queue if is_def])
        return emitted
    askable: list[tuple[dict, bool, "contract.Question"]] = []
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
        ev["_attempts"] = attempts
        askable.append((entry, is_deferred, _question(ev)))
    # Fan-out ask: ONE batched call for 2+ questions, one ask for a single.
    # A whole-call failure leaves every slot None -> "jev-error" per event
    # (fail closed, no park).
    answers: list = [None] * len(askable)
    if askable and jev is not None:
        qlist = [q for _, _, q in askable]
        try:
            if len(qlist) >= 2:
                old_url = os.environ.get("HNGH_JEV_URL")
                if leg_url:  # legs route the local lane; ask_batch takes no base_url
                    os.environ["HNGH_JEV_URL"] = leg_url
                try:
                    got = jev.ask_batch(qlist)
                finally:
                    if old_url is None:
                        os.environ.pop("HNGH_JEV_URL", None)
                    else:
                        os.environ["HNGH_JEV_URL"] = old_url
            else:
                got = [jev.ask(qlist[0], base_url=leg_url)]
            answers = (list(got) + answers)[:len(askable)]
        except Exception:
            pass
    for j, ((entry, is_deferred, _q), ans) in enumerate(zip(askable, answers)):
        ev, attempts = entry["event"], entry["attempts"]
        used, park, tok, stop = _handle(d, ev, attempts, emitted, ans,
                                        is_def=is_deferred, exhausted=exhausted)
        spent += tok
        _save_budget(d, date, spent)
        if park:  # triage.deferred lives in STATE now, not as a ledger kind
            still.append({"event": {k: v for k, v in ev.items() if k != "_attempts"},
                          "attempts": used})
        if stop:  # dispatch cap: no further dispatch-classified asks this beat
            for e2, is_def2, _q2 in askable[j + 1:]:
                if is_def2:
                    still.append(e2)
            break
    _save_deferred(d, still)
    st = _state(d)
    st["exhausted"] = sorted(exhausted)
    _write_state(d, st)
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
        fake = lambda q, **kw: seq.pop(0) if seq else contract.Answer(
            contract.Verdict.ESCALATE, "escalate", (), q.state_version)
        with mock.patch.object(sys.modules[__name__], "_open_beads",
                               return_value=(list(beads), "")), \
                mock.patch.object(jev, "ask", side_effect=jev_fx or fake), \
                mock.patch.object(jev, "ask_batch",
                                  side_effect=lambda qs: [(jev_fx or fake)(q) for q in qs]):
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

    # Escalate parks with accumulating attempts; at the cap one final
    # attempts-exhausted escalation, then the bead leaves the loop
    # (halt condition) until the bead closes and the exhausted set purges.
    os.environ["HNGH_ATTEMPT_CAP"] = "2"
    try:
        tmp, d, out = run_case(
            [_row("b-x")],
            [contract.Answer(contract.Verdict.ESCALATE, "escalate", (), 0)])
        assert [e.kind for e in out] == ["escalation.filed"], out
        assert out[0].payload["reason"] == "jev-escalate", out[0].payload
        assert len(_deferred(d)) == 1 and _deferred(d)[0]["attempts"] == 1, _deferred(d)
        with mock.patch.object(
                jev, "ask",
                return_value=contract.Answer(contract.Verdict.ESCALATE, "escalate", (), 0)), \
                mock.patch.object(sys.modules[__name__], "_open_beads",
                                  return_value=([_row("b-x")], "")):
            out2 = beat(ledger_dir=d)
        assert [e.kind for e in out2] == ["escalation.filed"], out2
        assert out2[0].payload["reason"] == "attempts-exhausted", out2[0].payload
        assert _deferred(d) == [], _deferred(d)
        assert _state(d).get("exhausted") == ["b-x"], _state(d).get("exhausted")
        # Third beat: the exhausted bead is skipped — no ask, no events.
        with mock.patch.object(
                jev, "ask",
                side_effect=AssertionError("exhausted bead must not be asked")), \
                mock.patch.object(sys.modules[__name__], "_open_beads",
                                  return_value=([_row("b-x")], "")):
            out3 = beat(ledger_dir=d)
        assert out3 == [], out3
        assert _state(d).get("exhausted") == ["b-x"], _state(d).get("exhausted")
        # Purge: once the bead leaves bd's open set the halt unblocks.
        with mock.patch.object(jev, "ask",
                               side_effect=AssertionError("no beads, no ask")), \
                mock.patch.object(sys.modules[__name__], "_open_beads",
                                  return_value=([], "")):
            out4 = beat(ledger_dir=d)
        assert out4 == [], out4
        assert _state(d).get("exhausted") == [], _state(d).get("exhausted")
    finally:
        os.environ.pop("HNGH_ATTEMPT_CAP", None)
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
