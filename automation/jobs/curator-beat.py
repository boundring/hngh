#!/usr/bin/env python3
"""curator-beat — rehearsal-lane plan step 3 (docs/design/
rehearsal-and-self-order.md "Self-ordering: the curator beat").

Read-only consumer of the feed layer: enumerates work-graph nodes from
dashboard/plans.json (built by jobs/plan-feed.py, which reads the plan
ledger + queue.md), then RE-READS every plan it would act on from disk
(never edits a plan whose acceptance it did not re-read). Emits TSV
rows `verb<TAB>detail` on stdout; the cadence/day wrapper files them
as STATE.md breadcrumbs (operator-item events: flagged/needs). Two
machine actions (priority flag, duplicate-scope merge proposal) and
two report verbs (deck handoff, enabling-work staging), all dry —
plan-file mutations land only through scripts/ceremony-drive, never
here. Guardrails (2026-09-09 disposition sweep): never risk=critical,
never already-parked, landed steps mean no action, references must
exist; when in doubt, leave it live. Fail-closed: exit 0 on every
expected path.
"""
import json
import os
import re
import sys
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOME = os.environ.get("HNGH_HOME",
                      os.path.join(os.path.expanduser("~"),
                                   "Projects", "etc", "hngh"))
PLANS_JSON = os.environ.get("HNGH_PLANS_FEED_OUT",
                            os.path.join(ROOT, "dashboard", "plans.json"))
PLANS_DIR = os.path.join(HOME, "docs", "project", "plans")

# Front-matter conventions copied from jobs/plan-feed.py (the feed is
# the contract; the curator re-reads disk with the same regexes).
FRONT = re.compile(r"<!--\s*plan:\s*status=(\w+)\s+risk=(\w+)"
                   r"\s+accepted=([^\s>]+)[^>]*-->")
PRIO = re.compile(r"\bpriority=(\w+)")
CAUSE = re.compile(r"\bcause=([\w-]+)")
ROUTED = re.compile(r"\brouted-from=([\w:.-]+)")
PLANREF = re.compile(r"docs/project/plans/([\w.-]+)\.plan\.md")
DECK = re.compile(r"DECK-NODE\.md|deck node|deck-side", re.I)
STEP_DONE = re.compile(r"^\s*- \[x\]", re.M)


def now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_plan(path):
    """Disk-authoritative read of one plan. None when not a plan file."""
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return None
    first = text.split("\n", 1)[0]
    m = FRONT.search(first)
    if not m:
        return None
    body = text
    return {
        "slug": os.path.basename(path)[:-len(".plan.md")],
        "status": m.group(1), "risk": m.group(2), "accepted": m.group(3),
        "priority": bool(PRIO.search(first)),
        "cause": CAUSE.search(first).group(1) if CAUSE.search(first) else None,
        "routed": ROUTED.search(first).group(1) if ROUTED.search(first) else None,
        "done": len(STEP_DONE.findall(body)),
        "refs": set(PLANREF.findall(text)),
        "deck": bool(DECK.search(text)),
    }


def emit(verb, detail):
    print(f"{verb}\t{detail}")


def main():
    try:
        feed = json.load(open(PLANS_JSON, encoding="utf-8"))
        slugs = [p["slug"] for p in feed.get("plans", [])]
        qnext = feed.get("queue_next") or "-"
    except (OSError, ValueError, KeyError, TypeError):
        emit("refused", "plans.json unreadable — feed layer missing; "
                        "run jobs/plan-feed.py first")
        return 0
    plans = {}
    for s in slugs:
        p = parse_plan(os.path.join(PLANS_DIR, s + ".plan.md"))
        if p:
            plans[s] = p
    # live = accepted or executed (the work graph's live nodes)
    live = {s: p for s, p in plans.items()
            if p["status"] in ("accepted", "executed")}
    ok = {s: p for s, p in plans.items() if p["status"] == "accepted"}
    # referenced-by index over live plans' bodies (targets must exist)
    refby = {}
    for s, p in live.items():
        for t in p["refs"]:
            if t != s and os.path.isfile(os.path.join(PLANS_DIR,
                                                      t + ".plan.md")):
                refby.setdefault(t, []).append(s)
    out = []
    # verb 1 — flag: accepted, never started, referenced by a live plan
    for s, p in ok.items():
        if p["risk"] == "critical" or p["priority"] or p["done"] or s not in refby:
            continue
        out.append("flagged\tpriority=high proposal for %s "
                   "(referenced by %s; 0 steps done) — needs ceremony flag"
                   % (s, ",".join(sorted(refby[s]))))
    # verb 2 — merge: park older duplicate routed-from carriers
    byid = {}
    for s, p in ok.items():
        if p["routed"]:
            byid.setdefault(p["routed"], []).append(s)
    for ident, sibs in byid.items():
        if len(sibs) < 2:
            continue
        sibs.sort(key=lambda s: plans[s]["accepted"])
        for s in sibs[:-1]:
            p = plans[s]
            if p["risk"] == "critical" or p["cause"] or p["done"]:
                continue
            out.append("needs\tparking proposal %s cause=duplicate "
                       "disposed=%s reason=\"identity %s; newest carrier %s "
                       "stays live; 0 steps landed\""
                       % (s, now(), ident, sibs[-1]))
    # verb 3 — handoff (report only): plans fitting the deck node
    for s, p in ok.items():
        if p["deck"] and p["risk"] != "critical":
            out.append("flagged\tdeck node handoff (DECK-NODE.md Phase 3): "
                       "%s" % s)
    # verb 4 — staging (report only): enabling-work edges for the
    # selector/gantt; annotation evidence, never queue surgery
    for s, p in live.items():
        if p["risk"] == "critical":
            continue
        for t in sorted(p["refs"]):
            if t != s and t in plans:
                out.append("needs\tenabling-work edge needs staging: "
                           "%s -> %s" % (s, t))
    if out:
        emit("context", "queue_next=%s plans=%d" % (qnext, len(plans)))
        for row in out:
            print(row)
    return 0


if __name__ == "__main__":
    sys.exit(main())
