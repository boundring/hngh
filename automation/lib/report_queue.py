#!/usr/bin/env python3
"""report_queue - the one shared report-queue row shim.

One row per report() call behind the kernel scripts/report-queue --add.
The kernel owns the dedup contract: a repeat with the SAME identity
inside window SECONDS bumps the existing row's ` ×N` marker (not a new
row); with evidence, only a changed evidence token re-fires (same
evidence = a stale condition, suppressed). Fail-closed advisory: a lost
row is swallowed (False), never a crash.

Terminal silence (P1d, 2026-09-25): every identity row carries
`expires=<ISO ts>` in its text (default first-seen + 7d). An identity
still re-firing past its expiry escalates ONCE -- one `expired:<ident>`
alert row for the operator -- and every further re-fire is swallowed
silently (False). Re-arm by removing its entry from the identity state
file (HNGH_REPORT_IDENTITIES, default automation/state/report-identities.json).

usage: report(kind, text, identity=None, window=None, evidence=None,
              binary=None, root=None, expires=None) -> bool
    True when the row landed (exit 0), False on any fault or when the
    terminal-silence policy swallowed the filing.
    binary: report-queue path (default <repo>/scripts/report-queue;
    callers pass their own env-seamed constant).
    root: report root injected as HNGH_REPORT_ROOT (default: inherit the
    environment untouched - callers that never injected keep not doing).
    expires: ISO ts overriding the 7d default (identity rows only).
"""
import json
import os
import subprocess
from datetime import datetime, timedelta, timezone

REPO = os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__))))
EXPIRES_DAYS = 7  # terminal silence default (P1d)


def _now():
    return datetime.now(timezone.utc)


def _iso(dt):
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def _identity_path():
    return os.environ.get("HNGH_REPORT_IDENTITIES") or os.path.join(
        REPO, "automation", "state", "report-identities.json")


def _load_state():
    """Identity state ({ident: {expires, escalated}}); {} on any fault.
    Entries are kept forever: terminal silence is TERMINAL -- only the
    operator clearing the entry re-arms an identity."""
    try:
        with open(_identity_path()) as fh:
            state = json.load(fh)
    except (OSError, ValueError):
        return {}
    return {k: v for k, v in state.items() if isinstance(v, dict)}


def _save_state(state):
    try:
        with open(_identity_path(), "w") as fh:
            json.dump(state, fh, sort_keys=True)
    except OSError:
        pass  # a lost state entry may re-escalate once; never crash


def _file(kind, text, identity=None, window=None, evidence=None,
          binary=None, root=None):
    argv = [binary or os.path.join(REPO, "scripts", "report-queue"),
            "--add", kind, text]
    if identity is not None:
        argv += ["--identity", identity]
    if window is not None:
        argv += ["--window", str(window)]
    if evidence:  # the evidence-token policy, single-sourced here
        argv += ["--evidence", evidence]
    env = dict(os.environ, HNGH_REPORT_ROOT=root) if root is not None else None
    try:
        r = subprocess.run(argv, env=env, stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, timeout=30)
        return r.returncode == 0
    except Exception:
        return False  # a lost report row must not block the caller


def report(kind, text, identity=None, window=None, evidence=None,
           binary=None, root=None, expires=None):
    if identity is not None:
        state = _load_state()
        entry = state.get(identity)
        if entry is None:
            entry = {"expires": expires or _iso(
                _now() + timedelta(days=EXPIRES_DAYS)), "escalated": False}
            state[identity] = entry
            _save_state(state)
        if _iso(_now()) > entry["expires"]:
            if entry["escalated"]:
                return False  # terminal silence
            entry["escalated"] = True
            _save_state(state)
            _file(
                "alert",
                "identity expired: %s cannot close within its window "
                "(expires=%s); auto-parked after one operator escalation -- "
                "close the condition or re-arm by clearing its identity "
                "state" % (identity, entry["expires"]),
                identity="expired:%s" % identity, binary=binary, root=root)
            return False  # the plain filing is replaced by the escalation
        if "expires=%s" % entry["expires"] not in text:
            text = "%s expires=%s" % (text, entry["expires"])
    return _file(kind, text, identity=identity, window=window,
                 evidence=evidence, binary=binary, root=root)
