#!/usr/bin/env python3
"""telemetry — append one event row to the cadence telemetry store (capture-first).

Store: dashboard/telemetry.db (sqlite, WAL). Schema is additive-only;
capture before views — no readers live here yet. Best-effort by design:
any fault exits 0 silently so telemetry can never fail a tick.

usage: jobs/telemetry.py emit --kind K --source S [--identity I] [--model M]
         [--wall-s F] [--subject T] [--refs R] [--body B]
         [--data '{"tokens_in":N,"tokens_out":N,"cost_usd":F,"lane":L,"unit":U}']
"""
import argparse
import json
import os
import sqlite3
import sys
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB = os.path.join(ROOT, "dashboard", "telemetry.db")

SCHEMA = """CREATE TABLE IF NOT EXISTS events(
  ts TEXT, source TEXT, kind TEXT, identity TEXT, lane TEXT, unit TEXT,
  model TEXT, tokens_in INTEGER, tokens_out INTEGER, cost_usd REAL,
  wall_s REAL, subject TEXT, refs TEXT, body TEXT)"""

DATA_FIELDS = ("lane", "unit", "tokens_in", "tokens_out", "cost_usd")


def emit(args):
    extra = {}
    if args.data:
        parsed = json.loads(args.data)
        bad = set(parsed) - set(DATA_FIELDS)
        if bad:
            raise ValueError("unsupported --data keys: %s" % ",".join(sorted(bad)))
        extra = parsed
    os.makedirs(os.path.dirname(DB), exist_ok=True)
    conn = sqlite3.connect(DB, timeout=10)
    try:
        conn.execute("PRAGMA journal_mode=WAL")
        conn.execute(SCHEMA)
        conn.execute(
            "INSERT INTO events(ts, source, kind, identity, lane, unit, model,"
            " tokens_in, tokens_out, cost_usd, wall_s, subject, refs, body)"
            " VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
            (datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
             args.source, args.kind, args.identity, extra.get("lane"),
             extra.get("unit"), args.model, extra.get("tokens_in"),
             extra.get("tokens_out"), extra.get("cost_usd"), args.wall_s,
             args.subject, args.refs, args.body))
        conn.commit()
    finally:
        conn.close()


def main():
    p = argparse.ArgumentParser(prog="telemetry.py")
    sub = p.add_subparsers(dest="cmd", required=True)
    e = sub.add_parser("emit")
    e.add_argument("--kind", required=True)
    e.add_argument("--source", required=True)
    e.add_argument("--identity")
    e.add_argument("--model")
    e.add_argument("--wall-s", type=float)
    e.add_argument("--subject")
    e.add_argument("--refs")
    e.add_argument("--body")
    e.add_argument("--data", help='JSON: {"tokens_in":N,...} (lane, unit,'
                                    " tokens_in, tokens_out, cost_usd)")
    args = p.parse_args()
    try:
        emit(args)
    except Exception:
        pass  # best-effort: telemetry never fails a tick
    sys.exit(0)


if __name__ == "__main__":
    main()
