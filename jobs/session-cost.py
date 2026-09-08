#!/usr/bin/env python3
"""session-cost — capture one telemetry row per finished omp session.

Spec: docs/design/ledger-and-records-spec.md §3 (session-cost capture).
Token usage, model and duration are parsed from ~/.omp/agent/sessions
transcripts; discovery is reused from jobs/sessions-feed.py
(omp_candidates — 24h window, newest first, capped). Per-agent transcripts
are grouped under their parent session id, so one row carries the
session's total spend. Emits through jobs/telemetry.py emit
(kind=session-cost, identity=<session uuid>): idempotent — a session
already in the store is skipped; live sessions (any member file modified
in the last 10 min) defer to a later pass. A transcript without usage
data lands with null token/cost fields, never a failure. Exit 0 always.

Ceiling: a row is a point-in-time sum — a session resumed after its row
was captured is not re-emitted (strict idempotence); re-capture needs
identity versioning later.
"""
import importlib.util
import json
import os
import sqlite3
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

_spec = importlib.util.spec_from_file_location(
    "sessions_feed", os.path.join(ROOT, "jobs", "sessions-feed.py"))
sessions_feed = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sessions_feed)

TELEMETRY = os.path.join(ROOT, "jobs", "telemetry.py")
DB = os.path.join(ROOT, "dashboard", "telemetry.db")
LIVE_GRACE_S = 600


def parse_transcript(path):
    """One pass: (sid, model_counts, tokens_in, tokens_out, cost_usd,
    first_ts, last_ts, usage_msgs)."""
    models = {}
    tin = tout = 0
    cost = 0.0
    sid = None
    first_ts = last_ts = None
    usage_msgs = 0
    try:
        with open(path, errors="replace") as fh:
            for ln in fh:
                try:
                    d = json.loads(ln)
                except ValueError:
                    continue
                ts = d.get("timestamp")
                if ts:
                    if first_ts is None:
                        first_ts = ts
                    last_ts = ts
                if sid is None and d.get("type") == "session":
                    sid = d.get("id")
                m = d.get("message") or {}
                u = m.get("usage")
                if u:
                    usage_msgs += 1
                    tin += u.get("input") or 0
                    tout += u.get("output") or 0
                    cost += (u.get("cost") or {}).get("total") or 0
                    mod = m.get("model")
                    if mod:
                        models[mod] = models.get(mod, 0) + 1
    except OSError:
        pass
    return sid, models, tin, tout, cost, first_ts, last_ts, usage_msgs


def captured_identities():
    """identity set already in the store for kind=session-cost."""
    if not os.path.exists(DB):
        return set()
    try:
        conn = sqlite3.connect("file:%s?mode=ro" % DB, uri=True)
        try:
            return set(r[0] for r in conn.execute(
                "SELECT DISTINCT identity FROM events WHERE kind='session-cost'"))
        finally:
            conn.close()
    except sqlite3.Error:
        return set()


def main():
    now = time.time()
    groups = {}  # sid -> session aggregate
    for cand in sessions_feed.omp_candidates(now):
        sid, models, tin, tout, cost, first_ts, last_ts, usage = \
            parse_transcript(cand["path"])
        key = sid or "path:%s" % cand["path"]
        g = groups.setdefault(key, {
            "models": {}, "tin": 0, "tout": 0, "cost": 0.0, "usage": 0,
            "first": None, "last": None, "mtime": 0, "subject": ""})
        for k, v in models.items():
            g["models"][k] = g["models"].get(k, 0) + v
        g["tin"] += tin
        g["tout"] += tout
        g["cost"] += cost
        g["usage"] += usage
        g["mtime"] = max(g["mtime"], cand["mtime"])
        if first_ts and (g["first"] is None or first_ts < g["first"]):
            g["first"] = first_ts
        if last_ts and (g["last"] is None or last_ts > g["last"]):
            g["last"] = last_ts
        # subject: prefer the main (timestamped) transcript's mission
        main = cand["stem"][:2] == "20"
        if main or not g["subject"]:
            g["subject"] = sessions_feed.omp_mission(cand)

    done = captured_identities()
    emitted = deferred = skipped = 0
    for sid, g in sorted(groups.items()):
        if now - g["mtime"] < LIVE_GRACE_S:
            deferred += 1
            continue
        if sid in done:
            skipped += 1
            continue
        wall = None
        if g["first"] and g["last"]:
            t0 = sessions_feed._iso_ts(g["first"])
            t1 = sessions_feed._iso_ts(g["last"])
            if t0 is not None and t1 is not None and t1 >= t0:
                wall = round(t1 - t0, 1)
        model = max(g["models"], key=g["models"].get) if g["models"] else None
        cmd = [sys.executable, TELEMETRY, "emit", "--kind", "session-cost",
               "--source", "session-cost", "--identity", sid,
               "--subject", g["subject"] or sid]
        if model:
            cmd += ["--model", model]
        if wall is not None:
            cmd += ["--wall-s", "%.1f" % wall]
        if g["usage"]:
            cmd += ["--data", json.dumps({
                "tokens_in": g["tin"], "tokens_out": g["tout"],
                "cost_usd": round(g["cost"], 6)})]
        subprocess.run(cmd, stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL)
        emitted += 1
    print("session-cost: emitted %d, deferred-live %d, already-captured %d"
          % (emitted, deferred, skipped))


if __name__ == "__main__":
    main()
