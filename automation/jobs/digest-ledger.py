#!/usr/bin/env python3
"""digest-ledger — emit the "NEWS FROM THE MEGASTRUCTURE" block for the
daily digest (automation/digest/<date>.md). Every number is read from a
real feed; each section cites its source file in an HTML comment. ASCII
output; fail-closed (exit 0, empty output on fault) so the digest write
path can never break ping-hourly.

usage: jobs/digest-ledger.py <YYYY-MM-DD>
"""
import json
import os
import sqlite3
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TELEMETRY = os.path.join(ROOT, "dashboard", "telemetry.db")
BUDGET_LOG = os.path.join(ROOT, "logs", "budget.md")
PLANS_JSON = os.path.join(ROOT, "dashboard", "plans.json")
OPERATOR_ITEMS = os.path.join(ROOT, "dashboard", "operator-items.json")
RESEARCH_LINES = os.path.join(ROOT, "research-lines.tsv")
STATE_MD = os.path.join(ROOT, "STATE.md")


def _ascii(text):
    return str(text).encode("ascii", "replace").decode("ascii")


def spend(date, db=TELEMETRY):
    """Metered spend + token volume for the day, from telemetry events."""
    if not os.path.isfile(db):
        return None
    try:
        conn = sqlite3.connect("file:%s?mode=ro" % db, uri=True, timeout=5)
        row = conn.execute(
            "SELECT COUNT(*), SUM(COALESCE(cost_usd,0)), SUM(COALESCE(tokens_in,0)),"
            " SUM(COALESCE(tokens_out,0)) FROM events"
            " WHERE ts LIKE ? || 'T%'", (date,)).fetchone()
        conn.close()
        return row
    except Exception:
        return None


def sessions(date, path=BUDGET_LOG):
    """Sessions launched today, from the overnight budget ledger."""
    rows = []
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                if line.startswith(date):
                    parts = [p.strip() for p in line.split("|")]
                    rows.append(parts)
    except Exception:
        pass
    return rows


def plans(date, path=PLANS_JSON):
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except Exception:
        return None
    entries = data.get("plans") or []
    accepted = [p for p in entries
                if str(p.get("accepted", "")).startswith(date)]
    executed = [p for p in entries if p.get("status") == "executed"]
    return entries, accepted, executed, data.get("queue_next")


def operator_items(path=OPERATOR_ITEMS):
    try:
        with open(path, encoding="utf-8") as f:
            items = json.load(f).get("items") or []
    except Exception:
        return None
    open_items = [i for i in items if i.get("status") == "open"]
    newest = sorted(items, key=lambda i: i.get("first_seen", ""),
                    reverse=True)[:3]
    return items, open_items, newest


def research_lines(path=RESEARCH_LINES):
    counts = {}
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                parts = line.rstrip("\n").split("\t")
                if len(parts) >= 2:
                    counts[parts[1]] = counts.get(parts[1], 0) + 1
    except Exception:
        pass
    return counts


def posture(date, path=STATE_MD):
    crumbs = []
    try:
        with open(path, encoding="utf-8") as f:
            for line in f:
                if line.startswith(date) and " alert " in line:
                    crumbs.append([p.strip() for p in line.split("|")])
    except Exception:
        pass
    return crumbs


def build(date, feeds=None):
    """Return the megastructure block: one line per feed, source cited."""
    feeds = feeds or {}
    out = []
    s = feeds.get("spend", spend(date))
    if s and s[0]:
        out.append("<!-- feeds: dashboard/telemetry.db -->")
        out.append("- spend: $%.2f metered across %d calls today;"
                   " tokens in %d, out %d."
                   % (s[1] or 0.0, s[0], s[2] or 0, s[3] or 0))
    sess = feeds.get("sessions", sessions(date))
    if sess:
        last_lane = sess[-1][1] if len(sess[-1]) > 1 else "-"
        last_plan = last_lane.split("|", 1)[-1] if "|" in last_lane else last_lane
        lanes = set(p[1].split("|", 1)[0] for p in sess if len(p) > 1)
        out.append("<!-- feeds: logs/budget.md -->")
        out.append("- sessions: %d launched today across %d plan lane(s);"
                   " newest: %s at %s." % (len(sess), len(lanes),
                                           _ascii(last_plan),
                                           sess[-1][0][11:16]))
    p = feeds.get("plans", plans(date))
    if p is not None:
        entries, accepted, executed, queue_next = p
        out.append("<!-- feeds: dashboard/plans.json -->")
        out.append("- plans: %d recorded, %d accepted today, %d executed;"
                   " queue next: %s." % (len(entries), len(accepted),
                                         len(executed), queue_next or "-"))
    oi = feeds.get("operator_items", operator_items())
    if oi is not None:
        items, open_items, newest = oi
        out.append("<!-- feeds: dashboard/operator-items.json -->")
        out.append("- operator items: %d open of %d; newest: %s"
                   % (len(open_items), len(items),
                      _ascii(newest[0]["text"][:80]) if newest else "none"))
    rl = feeds.get("research_lines", research_lines())
    if rl:
        order = ("planned", "expanding", "contracting", "reviewed")
        out.append("<!-- feeds: research-lines.tsv -->")
        out.append("- research lines: %s."
                   % ", ".join("%s %d" % (k, rl[k]) for k in order
                               if rl.get(k)))
    crumbs = feeds.get("posture", posture(date))
    if crumbs:
        scripts = sorted(set(c[1] for c in crumbs if len(c) > 1))
        out.append("<!-- feeds: STATE.md -->")
        out.append("- posture: %d alert crumbs today (%s); last: %s."
                   % (len(crumbs), ", ".join(_ascii(x) for x in scripts),
                      _ascii(crumbs[-1][3][:70]) if len(crumbs[-1]) > 3 else "-"))
    return out


def main(argv):
    if len(argv) != 2:
        return 0
    day = argv[1]
    try:
        block = build(day)
    except Exception:
        return 0
    if not block:
        return 0
    print("")
    print("### NEWS FROM THE MEGASTRUCTURE %s" % day)
    print()
    print("\n".join(block))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
