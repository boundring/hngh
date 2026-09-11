#!/usr/bin/env python3
"""ocgo-attribution — turn opencode's local attribution surface into the
telemetry rows the ocgo HTTP leg already emits (R2, design
docs/research/2026-09-10-opencode-agentic-surface.md s6).

Input: the launcher's `opencode run --format json` event stream (one JSON
event per line; step_finish parts carry tokens{input,output} and cost).
For session ids the stream only names, the opencode.db message table is
the fallback (assistant rows carry cost/tokens/modelID/providerID/time).

Emits one row per hngh-keyed session through jobs/telemetry.py's schema:
kind=model, source=ocgo-agent, identity=<opencode session id> (idempotent:
a session already in the store is skipped), model=provider/model. Only
spend inside the 5h pacer window (quota_pace_blocked_5h) is attributed;
stale messages are never counted. Best-effort: any fault exits 0 so
attribution can never fail a session's cleanup.
"""
import argparse
import json
import os
import sqlite3
import sys
import time
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "jobs"))
import telemetry  # same write mechanism, never a second schema

WINDOW_MS = 5 * 3600 * 1000  # the 5h pacer window


def parse_stream(path, cutoff_ms):
    """-> {session_id: {"tokens_in","tokens_out","cost","first_ms","last_ms"}}"""
    per = {}
    try:
        fh = open(path, errors="replace")
    except OSError:
        return per
    with fh:
        for ln in fh:
            try:
                ev = json.loads(ln)
            except ValueError:
                continue
            sid = ev.get("sessionID")
            ts = ev.get("timestamp")
            if not sid or not isinstance(ts, int):
                continue
            s = per.setdefault(sid, {"tokens_in": 0, "tokens_out": 0,
                                     "cost": 0.0, "first_ms": ts, "last_ms": ts})
            s["first_ms"] = min(s["first_ms"], ts)
            s["last_ms"] = max(s["last_ms"], ts)
            if ts < cutoff_ms:
                continue
            part = ev.get("part") or {}
            if part.get("type") == "step-finish":
                s["tokens_in"] += (part.get("tokens") or {}).get("input") or 0
                s["tokens_out"] += (part.get("tokens") or {}).get("output") or 0
                s["cost"] += part.get("cost") or 0.0
    return per


def db_fallback(db, sid, cutoff_ms):
    """Sum assistant-message spend for one session id from opencode.db
    (read-only); (tokens_in, tokens_out, cost, model)."""
    try:
        conn = sqlite3.connect("file:%s?mode=ro" % db, uri=True, timeout=10)
    except sqlite3.Error:
        return 0, 0, 0.0, ""
    try:
        row = conn.execute(
            "select sum(cast(json_extract(data,'$.tokens.input') as integer)),"
            " sum(cast(json_extract(data,'$.tokens.output') as integer)),"
            " sum(cast(json_extract(data,'$.cost') as real)),"
            " coalesce(max(json_extract(data,'$.providerID')), ''),"
            " coalesce(max(json_extract(data,'$.modelID')), '')"
            " from message where session_id=? and"
            " json_extract(data,'$.role')='assistant' and"
            " cast(json_extract(data,'$.time.completed') as integer) >= ?",
            (sid, cutoff_ms)).fetchone()
    except sqlite3.Error:
        row = None
    finally:
        conn.close()
    if not row or row[0] is None:
        return 0, 0, 0.0, ""
    return (int(row[0]), int(row[1] or 0), float(row[2] or 0.0),
            "/".join(x for x in (row[3], row[4]) if x))


def emit_rows(per, telemetry_db, source):
    """One row per session not already in the store."""
    done = set()
    if os.path.exists(telemetry_db):
        try:
            conn = sqlite3.connect(telemetry_db, timeout=10)
            done = {r[0] for r in conn.execute(
                "select identity from events where kind='model' and source=?"
                " and identity is not null", (source,))}
            conn.close()
        except sqlite3.Error:
            pass
    for sid, s in sorted(per.items()):
        if sid in done:
            continue
        data = {}
        if s["tokens_in"] or s["tokens_out"]:
            data["tokens_in"] = s["tokens_in"]
            data["tokens_out"] = s["tokens_out"]
        if s["cost"]:
            data["cost_usd"] = s["cost"]
        wall = s["last_ms"] - s["first_ms"]
        telemetry.emit(argparse.Namespace(
            kind="model", source=source, identity=sid,
            model=s.get("model", ""), wall_s=wall / 1000.0,
            subject="ocgo-attribution.py", refs=None, body=None,
            data=json.dumps(data) if data else None))


def extract_plain(stream, plain):
    """The classifier consumes plain text (lib/causes.sh keyword matching):
    every text part, in order, verbatim."""
    try:
        with open(stream, errors="replace") as fh, open(plain, "a") as out:
            for ln in fh:
                try:
                    ev = json.loads(ln)
                except ValueError:
                    continue
                t = (ev.get("part") or {}).get("text")
                if ev.get("type") == "text" and t:
                    out.write(t + "\n")
    except OSError:
        pass


def main():
    p = argparse.ArgumentParser(prog="ocgo-attribution.py")
    p.add_argument("stream", help="opencode run --format json event log")
    p.add_argument("--db", default=os.path.expanduser(
        "~/.local/share/opencode/opencode.db"))
    p.add_argument("--telemetry", default=telemetry.DB)
    p.add_argument("--source", default="ocgo-agent")
    p.add_argument("--plain", help="plain-text log path for classify_cause")
    args = p.parse_args()
    try:
        telemetry.DB = args.telemetry
        cutoff = int(time.time() * 1000) - WINDOW_MS
        per = parse_stream(args.stream, cutoff)
        for sid in list(per):
            s = per[sid]
            tin, tout, cost, model = db_fallback(args.db, sid, cutoff)
            s["model"] = model
            if not (s["tokens_in"] or s["tokens_out"] or s["cost"]
                    or tin or tout or cost):
                del per[sid]  # nothing attributable: not a hngh-keyed spend
                continue
            if not (s["tokens_in"] or s["tokens_out"] or s["cost"]):
                s.update(tokens_in=tin, tokens_out=tout, cost=cost)
        emit_rows(per, args.telemetry, args.source)
        if args.plain:
            extract_plain(args.stream, args.plain)
    except Exception:
        pass  # best-effort: attribution never fails a session's cleanup
    sys.exit(0)


if __name__ == "__main__":
    main()
