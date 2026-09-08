#!/usr/bin/env python3
"""telemetry-report — first read-only consumer of the telemetry store.

SELECT-only over dashboard/telemetry.db (schema owned by telemetry.py;
capture-first — this is the reader side). Fail-closed: a missing or
unreadable store prints a notice and exits 0; a report never crashes a
caller.

usage: jobs/telemetry-report.py [--day YYYY-MM-DD] [--db PATH]
"""
import argparse
import os
import sqlite3
import sys
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_DB = os.path.join(ROOT, "dashboard", "telemetry.db")


def open_ro(db):
    if not os.path.exists(db):
        return None
    try:
        return sqlite3.connect("file:%s?mode=ro" % db, uri=True)
    except sqlite3.Error:
        return None


def main():
    p = argparse.ArgumentParser(prog="telemetry-report")
    p.add_argument("--day", default=datetime.now(timezone.utc).strftime("%Y-%m-%d"),
                   help="UTC day filter, YYYY-MM-DD (default: today)")
    p.add_argument("--db", default=DEFAULT_DB)
    args = p.parse_args()

    conn = open_ro(args.db)
    if conn is None:
        print("telemetry-report: no telemetry store at %s — nothing to report" % args.db)
        sys.exit(0)

    day = args.day + "%"
    try:
        print("telemetry report — %s (db: %s)" % (args.day, args.db))

        rows = conn.execute(
            "SELECT source, kind, COUNT(*) FROM events WHERE ts LIKE ?"
            " GROUP BY source, kind ORDER BY 3 DESC, 1, 2", (day,)).fetchall()
        print("\nevents by source/kind:")
        if rows:
            for source, kind, n in rows:
                print("  %-16s %-14s %5d" % (source, kind, n))
            print("  %-31s %5d" % ("total", sum(r[2] for r in rows)))
        else:
            print("  (no events)")

        rows = conn.execute(
            "SELECT subject, COUNT(*), ROUND(COALESCE(SUM(wall_s),0),1)"
            " FROM events WHERE ts LIKE ? AND kind='research'"
            " GROUP BY subject ORDER BY 2 DESC, 1", (day,)).fetchall()
        print("\nresearch beats (kind=research):")
        if rows:
            print("  %-46s %5s %8s" % ("subject", "beats", "wall_s"))
            for subject, n, wall in rows:
                print("  %-46s %5d %8.1f" % (subject, n, wall))
        else:
            print("  (no research beats)")

        rows = conn.execute(
            "SELECT subject, model, tokens_in, tokens_out, cost_usd, wall_s"
            " FROM events WHERE ts LIKE ? AND kind='session-cost'"
            " ORDER BY ts", (day,)).fetchall()
        print("\nsession cost (kind=session-cost):")
        if rows:
            print("  %-38s %-28s %9s %9s" % ("session", "model", "tok_in", "tok_out"))
            total = sum(c for c in (r[4] for r in rows) if c is not None)
            for subject, model, tin, tout, cost, wall in rows:
                print("  %-38s %-28s %9s %9s" % (
                    subject or "?", model or "?",
                    str(tin) if tin is not None else "-",
                    str(tout) if tout is not None else "-"))
            if any(r[4] is not None for r in rows):
                # the email-digest headline parses this line for spend
                print("  session-cost total: $%.2f" % total)
        else:
            print("  (no session-cost rows yet)")
    except sqlite3.Error as e:
        print("telemetry-report: store unreadable (%s)" % e)
    finally:
        conn.close()
    sys.exit(0)


if __name__ == "__main__":
    main()
