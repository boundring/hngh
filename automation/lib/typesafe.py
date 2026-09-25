#!/usr/bin/env python3
# typesafe.py -- thin Jev/Typesafe inference wrapper (hngh fast lane).
# Contract: structured decisions (beat-skip, triage, redact, model-rank)
# go through Typesafe Noul/Choice/Score calls at ~0.6s each, NOT through
# agent-grade inference. Fail-closed: without TYPESAFE_API_KEY every
# helper returns None and the caller falls back to its existing path.
# Values are never logged. One breadcrumb per UTC day max on fallback.
"""Thin Typesafe wrapper: Noul/Choice/Score helpers, fail-closed.

Confidence floors by decision site (refoundation P8, strict
sufficiency): a decision counts only with a typed record at/above its
floor. Typed missing or below floor -> the decision PARKS and files one
typed-gap:<site> report-queue row (window 604800); the legacy output
stays advisory context, never the deciding input.

    ng/jev.py lane (CONF_MIN)                              0.5
    cadence/calendar/daily/06-review-disposition.sh (severity) 0.5
    cadence/hour/33-research-beat.sh (research verdict)    0.60
    scripts/overnight-cycle.sh (step-raise)                0.5
"""
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


def ask_nouls(state, questions) -> dict[str, float | None]:
    """Batched Noul questions -> {name: value in [0,1] or None}; every
    value None fail-closed. ONE system_one call for every question (the
    shared state is paid once). questions maps name -> instructions.
    """
    if not questions:
        return {}
    c = _client()
    if c is None:
        _crumb(",".join(questions))
        return {name: None for name in questions}
    try:
        from typesafe_sdk import Noul

        with c:
            r = c.system_one(
                state=state,
                questions={
                    name: Noul(instructions=instructions)
                    for name, instructions in questions.items()
                },
                model="jev-1.13.0",
            )
        return {
            name: getattr(r.nouls.get(name), "noul", None)
            for name in questions
        }
    except Exception:
        _crumb(",".join(questions))
        return {name: None for name in questions}


def ask_choice(state, name, instructions, criteria):
    """Choice question -> (winning key, confidence), (None, None) fail-closed."""
    return ask_choices(state, {name: (instructions, criteria)}).get(
        name, (None, None))


def ask_choices(state, questions):
    """Batched Choice questions -> {name: (winning key, confidence)},
    {} fail-closed. ONE system_one call for every question (parallel_questions
    fan-out: the shared state is paid once). questions maps name ->
    (instructions, criteria list).
    """
    c = _client()
    if c is None:
        _crumb(",".join(questions))
        return {}
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
                    for name, (instructions, criteria) in questions.items()
                },
                model="jev-1.13.0",
            )
        return {
            name: (
                getattr(r.choices[name], "choice", None),
                getattr(r.choices[name], "confidence", None),
            )
            for name in questions
        }
    except Exception:
        _crumb(",".join(questions))
        return {}


def arbiter(typed, legacy, labels, min_conf=0.5):
    """Pure precedence, the whole policy surface: typed wins when it is in
    labels with confidence >= min_conf; else legacy wins when it is in
    labels; else None. Per-site tuning is min_conf only.
    """
    t_label, t_conf = typed if typed else (None, None)
    if t_label in labels and t_conf is not None and t_conf >= min_conf:
        return t_label
    if legacy in labels:
        return legacy
    return None


def ask_score(state, name, instructions, criteria):
    """Score question -> float position, or None fail-closed."""
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
        return r.scores[name].score
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
        scores = r.scores["urgency"].score
        return (hot, (col is not None and col >= 0.5), scores)
    except Exception:
        _crumb("triage_fanout")
        return (None, None, None)


def triage_glue(city_json, urgency=False):
    """Whole per-beat triage glue, hoisted from the byte-identical inline
    python3 -c blocks in jobs/morning-digest.sh and
    cadence/hour/33-research-beat.sh: city-state JSON -> beats/beads
    state -> ONE triage_fanout -> the exact line each site consumed
    ('hottest=.. collapse=..' plus the top-2 'urgency=..' tail when
    urgency=True). Prints the line. Fail-open: no key -> the
    'hottest=? collapse=?' line as before; a broken payload raises -> no
    line and the caller proceeds untriaged (the sites' documented
    contract).
    """
    import json

    d = json.loads(city_json)
    st = {
        "beats": "beats " + d["timers"]["beats"],
        "beads": (str(d["beads"]["closed"]) + " closed "
                  + str(d["beads"]["open"]) + " open"),
    }
    lanes = ["reviewer-gates", "acp-probes", "contexts-redesign",
             "tiger-specs", "triage-wiring", "roles"]
    hot, col, scores = triage_fanout(st, lanes)
    parts = []
    parts.append("hottest=" + str(hot) if hot else "hottest=?")
    parts.append("collapse=" + str(col) if col is not None else "collapse=?")
    if urgency and scores:
        top = sorted(zip(lanes, scores), key=lambda kv: kv[1], reverse=True)[:2]
        parts.append("urgency=" + ",".join("%s:%.2f" % kv for kv in top))
    print(" ".join(parts))


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
    "studio_user_model": "name or empty", "studio_queue_depth": "int str",
    "verdict_age_s": "int str", "verdict_max_age_s": "int str"}.

    Studio-aware rule (hngh-f7j): verdict-age enforced FIRST and
    deterministically, before any inference call:
    - a verdict older than verdict_max_age_s (default 120s) is stale:
      return False (force refresh) regardless of the cached verdict.
    - a studio queue depth > 0 means the operator (or another lane)
      is using the box: return True (skip) without inference.
    - a loaded studio model different from the beat model means the
      operator loaded their own weights: return True (skip) without
      inference.
    Otherwise fall through to the operator_busy Noul; fail-open
    (False) when the key/SDK is missing or the call errors.
    """
    try:
        max_age = int(operator_active_signals.get("verdict_max_age_s",
                                                  "120"))
    except (TypeError, ValueError):
        max_age = 120
    try:
        age = int(operator_active_signals.get("verdict_age_s", "0"))
    except (TypeError, ValueError):
        age = 0
    if age > max_age:
        return False  # stale verdict: force refresh, never trust it
    try:
        qdepth = int(operator_active_signals.get("studio_queue_depth",
                                                 "0"))
    except (TypeError, ValueError):
        qdepth = 0
    if qdepth > 0:
        return True  # box busy: skip without spending inference
    beat_model = (operator_active_signals.get("beat_model") or "").strip()
    studio_model = (operator_active_signals.get("studio_user_model")
                      or "").strip()
    if studio_model and beat_model and studio_model != beat_model:
        return True  # operator's own weights loaded: skip
    v = ask_noul(
        state=operator_active_signals,
        name="operator_busy",
        instructions="Is the operator actively using the machine for their own work?",
    )
    if v is None:
        return False  # fail-open on fallback: existing guards decide
    return v >= 0.5


if __name__ == "__main__":
    if sys.argv[1:2] == ["triage"]:
        triage_glue(sys.stdin.read(), "urgency" in sys.argv[2:])
        sys.exit(0)
    v = ask_noul(
        state={"subject": "wrapper self-test"},
        name="working",
        instructions="Is this a self-test?",
    )
    print("noul:", v)
    sys.exit(0 if v is not None else 1)
