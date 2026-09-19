#!/usr/bin/env python3
# typesafe.py -- thin Jev/Typesafe inference wrapper (hngh fast lane).
# Contract: structured decisions (beat-skip, triage, redact, model-rank)
# go through Typesafe Noul/Choice/Score calls at ~0.6s each, NOT through
# agent-grade inference. Fail-closed: without TYPESAFE_API_KEY every
# helper returns None and the caller falls back to its existing path.
# Values are never logged. One breadcrumb per UTC day max on fallback.
"""Thin Typesafe wrapper: Noul/Choice/Score helpers, fail-closed."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "lib"))


def _client():
    key = os.environ.get("TYPESAFE_API_KEY")
    if not key:
        return None
    try:
        from typesafe_sdk import TypeSafeClient

        return TypeSafeClient()
    except ImportError:
        return None


def _crumb(msg):
    try:
        import subprocess

        subprocess.run(
            ["breadcrumb", "typesafe", "fallback", msg],
            capture_output=True,
            timeout=5,
        )
    except Exception:
        pass


def ask_noul(state, name, instructions):
    """Noul question -> float in [0,1], or None fail-closed."""
    c = _client()
    if c is None:
        _crumb(name)
        return None
    try:
        from typesafe_sdk import Noul

        with c:
            r = c.system_one(
                state=state, questions={name: Noul(instructions=instructions)}
            )
        return r.nouls[name].noul
    except Exception:
        _crumb(name)
        return None


def ask_choice(state, name, instructions, criteria):
    """Choice question -> winning key, or None fail-closed."""
    c = _client()
    if c is None:
        _crumb(name)
        return None
    try:
        from typesafe_sdk import Choice

        with c:
            r = c.system_one(
                state=state,
                questions={
                    name: Choice(
                        instructions=instructions,
                        criteria={k: None for k in criteria},
                    )
                },
            )
        return r.choices[name].choice
    except Exception:
        _crumb(name)
        return None


def ask_score(state, name, instructions, criteria):
    """Score question -> list of floats, or None fail-closed."""
    c = _client()
    if c is None:
        _crumb(name)
        return None
    try:
        from typesafe_sdk import Score

        with c:
            r = c.system_one(
                state=state,
                questions={
                    name: Score(
                        instructions=instructions,
                        criteria=list(criteria),
                    )
                },
            )
        return r.scores[name].scores
    except Exception:
        _crumb(name)
        return None


def triage_fanout(state, lanes):
    """Speculative lane fan-out (browser-use steal, hngh-ddc): ONE system_one
    round trip carrying every lane variant -- a Choice over lanes plus a
    Noul collapse check plus a Score over lane urgency. Only the matching
    branch executes: the caller runs the winning lane and acts on collapse
    iff its Noul fires. Fail-open: without key/SDK returns
    (None, None, None) and the caller proceeds untriaged.

    Returns (hottest_lane_or_None, collapse_bool_or_None, scores_or_None).
    """
    c = _client()
    if c is None:
        _crumb("triage_fanout")
        return (None, None, None)
    try:
        from typesafe_sdk import Choice, Noul, Score

        with c:
            r = c.system_one(
                state=state,
                questions={
                    "hottest": Choice(
                        instructions="Which work lane most needs attention next?",
                        criteria={k: None for k in lanes},
                    ),
                    "collapse_ready": Noul(
                        instructions="Is there absorbable completed work that should collapse now?"
                    ),
                    "urgency": Score(
                        instructions="Rate each lane's urgency.",
                        criteria=list(lanes),
                    ),
                },
            )
        hot = r.choices["hottest"].choice
        col = r.nouls["collapse_ready"].noul
        scores = r.scores["urgency"].scores
        return (hot, (col is not None and col >= 0.5), scores)
    except Exception:
        _crumb("triage_fanout")
        return (None, None, None)


def closeout_evidence_noul(state, summary):
    """Evidence Noul at bead close-out (browser-use DONE rule, hngh-ddc):
    a DONE claim requires independent verification -- this Noul answers
    whether the claimed evidence actually supports closing. Returns True
    (evidence supports close), False (gap -- do not close), or None
    fail-closed (no key/SDK/error: caller keeps its existing gate).
    """
    v = ask_noul(
        state=dict(state, close_claim=summary),
        name="close_evidence",
        instructions=(
            "Does the stated close-out evidence actually verify the work "
            "claimed (named commits exist, tests cited green, artifacts "
            "present)? Answer no when evidence is missing or vague."
        ),
    )
    if v is None:
        return None
    return v >= 0.5


def beat_skip_gate(operator_active_signals):
    """First wired decision: True iff the beat should SKIP (operator busy).

    operator_active_signals: dict e.g. {"session_recent": "yes"/"no",
    "studio_user_model": "name or empty"}.
    """
    v = ask_noul(
        state=operator_active_signals,
        name="operator_busy",
        instructions="Is the operator actively using the machine for their own work?",
    )
    if v is None:
        return False  # fail-open on fallback: existing guards decide
    return v >= 0.5


if __name__ == "__main__":
    v = ask_noul(
        state={"subject": "wrapper self-test"},
        name="working",
        instructions="Is this a self-test?",
    )
    print("noul:", v)
    sys.exit(0 if v is not None else 1)
