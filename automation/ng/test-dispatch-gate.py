"""Dispatch-gate self-test: cap precedence, admit/refuse, defer survival, leg order."""
import os
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path
from unittest import mock

NG = Path(__file__).resolve().parent
sys.path.insert(0, str(NG))
import cadence  # noqa: E402
import contract  # noqa: E402
import tiering  # noqa: E402

FILE_ANS = contract.Answer(contract.Verdict.DONE, "file", (), 0)


@contextmanager
def _env(**kw):
    saved = {k: os.environ.get(k) for k in kw}
    for k, v in kw.items():
        if v is None:
            os.environ.pop(k, None)
        else:
            os.environ[k] = v
    try:
        yield
    finally:
        for k, v in saved.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v


def _row(bid, **extra):
    r = {"id": bid, "title": bid, "status": "open", "created_at": ""}
    r.update(extra)
    return r


def _beat(d, beads, answers=()):
    seq = list(answers)
    fake = lambda q, **kw: seq.pop(0) if seq else contract.Answer(
        contract.Verdict.ESCALATE, "escalate", (), q.state_version)
    with mock.patch.object(cadence.jev, "ask", side_effect=fake), \
            mock.patch.object(cadence, "_open_beads", return_value=(list(beads), "")):
        return cadence.beat(ledger_dir=d, max_events=16)


def main() -> None:
    # Cap precedence: env > tsv row > default 4.
    with _env(HNGH_DISPATCH_DAY_CAP=None):
        assert cadence._dispatch_cap() == 4, cadence._dispatch_cap()
    with _env(HNGH_DISPATCH_DAY_CAP="7"):
        assert cadence._dispatch_cap() == 7
    with _env(HNGH_DISPATCH_DAY_CAP="0"):
        assert cadence._dispatch_cap() == 0

    # Admit under cap; refuse at/over; counter persisted in STATE.
    with tempfile.TemporaryDirectory(prefix="dg-admit-") as tmp:
        d = Path(tmp)
        with _env(HNGH_DISPATCH_DAY_CAP="2"):
            assert cadence._dispatch_admit(d) is True
            assert cadence._dispatch_admit(d) is True
            assert cadence._dispatch_admit(d) is False
        row = cadence._state(d)["dispatch"]
        assert row["count"] == 2 and row["date"] == cadence._today(), row

    # Fresh bead dispatches under cap.
    with tempfile.TemporaryDirectory(prefix="dg-fresh-") as tmp:
        d = Path(tmp)
        with _env(HNGH_DISPATCH_DAY_CAP="5"):
            out = _beat(d, [_row("b-1")], [FILE_ANS])
        assert [e.kind for e in out] == ["slice.proposed"], out
        assert cadence._state(d)["dispatch"]["count"] == 1

    # At cap: refuse + escalation; deferred work survives to the next beat
    # and dispatches once the cap is raised.
    with tempfile.TemporaryDirectory(prefix="dg-defer-") as tmp:
        d = Path(tmp)
        cadence._save_deferred(d, [{"event": {"kind": "bead.ready", "state_version": 0,
                                              "payload": {"id": "b-def", "title": "x",
                                                          "age_days": 1}},
                                    "attempts": 0}])
        with _env(HNGH_DISPATCH_DAY_CAP="0"):
            out = _beat(d, [], [FILE_ANS])
        assert [e.kind for e in out] == ["escalation.filed"], out
        assert out[0].payload["reason"] == "dispatch-capped", out[0].payload
        assert out[0].payload["bead"] == "b-def", out[0].payload
        surv = cadence._deferred(d)
        assert len(surv) == 1 and surv[0]["attempts"] == 1, surv
        with _env(HNGH_DISPATCH_DAY_CAP=None):
            out2 = _beat(d, [], [FILE_ANS])
        assert [e.kind for e in out2] == ["slice.proposed"], out2
        assert cadence._deferred(d) == [], cadence._deferred(d)

    # Leg ordering: pre-paid before paid-cash, blocked last.
    legs = [{"kind": "cash", "url": "u-cash", "prepaid": False, "blocked": False},
            {"kind": "prepaid", "url": "u-pre", "prepaid": True, "blocked": False},
            {"kind": "prepaid", "url": "", "prepaid": True, "blocked": True}]
    assert [l["url"] for l in tiering.leg_order(legs)] == ["u-pre", "u-cash", ""]

    # Configured legs route the ask to the first pre-paid leg.
    with tempfile.TemporaryDirectory(prefix="dg-legs-") as tmp:
        d = Path(tmp)
        seen = {}

        def fake_ask(q, base_url=None, **kw):
            seen["url"] = base_url
            return contract.Answer(contract.Verdict.DONE, "close", (), q.state_version)

        with _env(HNGH_JEV_LEGS="cash=https://cash,prepaid=https://pre"), \
                mock.patch.object(cadence.jev, "ask", side_effect=fake_ask), \
                mock.patch.object(cadence, "_open_beads", return_value=([_row("b-9")], "")):
            out = cadence.beat(ledger_dir=d)
        assert seen["url"] == "https://pre", seen
        assert [e.kind for e in out] == ["bead.close"], out

    # All legs blocked: never ask, one escalation, deferred preserved.
    with tempfile.TemporaryDirectory(prefix="dg-nolegs-") as tmp:
        d = Path(tmp)
        cadence._save_deferred(d, [{"event": {"kind": "bead.ready", "state_version": 0,
                                              "payload": {"id": "b-def", "title": "x",
                                                          "age_days": 1}},
                                    "attempts": 0}])
        called = []

        def fake_ask2(q, base_url=None, **kw):
            called.append(base_url)
            return contract.Answer(contract.Verdict.DONE, "close", (), q.state_version)

        with _env(HNGH_JEV_LEGS="cash=,cash="), \
                mock.patch.object(cadence.jev, "ask", side_effect=fake_ask2), \
                mock.patch.object(cadence, "_open_beads", return_value=([_row("b-x")], "")):
            out = cadence.beat(ledger_dir=d)
        assert called == [], called
        reasons = [e.payload.get("reason") for e in out if e.kind == "escalation.filed"]
        assert reasons == ["legs-exhausted"], reasons
        assert len(cadence._deferred(d)) == 1, cadence._deferred(d)

    print("dispatch-gate self-check ok")


if __name__ == "__main__":
    main()
