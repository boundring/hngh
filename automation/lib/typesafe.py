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
