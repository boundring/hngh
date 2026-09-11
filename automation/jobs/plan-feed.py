#!/usr/bin/env python3
"""plan-feed — build dashboard/plans.json from the hngh plan ledger.

Reads docs/project/plans/*.plan.md front-matter (status, risk, accepted)
and writes a compact feed for the dashboard. Display-only; the ledger in
docs/project/plans/ is the source of truth. Fail-closed: any fault
leaves the previous feed in place and exits 0.
"""
import os
import re
import subprocess
import sys
import json

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.environ.get("HNGH_PLANS_FEED_OUT",
                     os.path.join(ROOT, "dashboard", "plans.json"))
HOME = os.environ.get("HNGH_HOME",
                      os.path.join(os.path.expanduser("~"),
                                   "Projects", "etc", "hngh"))
PLANS = os.path.join(HOME, "docs", "project", "plans")
QUEUE = os.path.join(HOME, "docs", "project", "queue.md")

FRONT = re.compile(r"<!--\s*plan:\s*status=(\w+)\s+risk=(\w+)"
                   r"\s+accepted=([^\s>]+)[^>]*-->")

# The queue.md `## Next` parse, same approach as scripts/omp-bridge
# (reused, never imported across repos).
NEXT_RE = re.compile(r"## Next\s*\n(.*?)(?=\n## |\Z)", re.S)
BULLET_ITEM = re.compile(r"^\s*(?:-\s*\*\*|1\.\s*\*\*|-\s+|1\.\s+)"
                         r"(?P<item>[^\n]+)", re.M)


def queue_next():
    """The current queue Next item id (from the `## Next` block)."""
    try:
        with open(QUEUE, encoding="utf-8") as fh:
            text = fh.read()
    except OSError:
        return None
    m = NEXT_RE.search(text)
    if m is None:
        return None
    mm = BULLET_ITEM.search(m.group(0))
    item = mm.group("item").strip() if mm else None
    return item.split("**")[0].strip() if item else None


def last_ceremony():
    """The last ceremony commit: subject starts word-on 'hngh: candidate'
    (the certificate-bound commit message ceremony-drive writes).
    HNGH_CEREMONY_LOG overrides the `git log` output (test seam); any
    fault is fail-closed None."""
    out = os.environ.get("HNGH_CEREMONY_LOG")
    if out is None:
        try:
            r = subprocess.run(
                ["git", "log", "--format=%H|%cs|%s", "-50"], cwd=HOME,
                capture_output=True, text=True, timeout=10)
        except (OSError, subprocess.SubprocessError):
            return None
        if r.returncode != 0:
            return None
        out = r.stdout
    for line in out.splitlines():
        pieces = line.split("|", 2)
        if len(pieces) == 3 and pieces[2].startswith("hngh: candidate"):
            return {"hash": pieces[0], "date": pieces[1],
                    "subject": pieces[2]}
    return None


def read_plans():
    out = []
    try:
        names = sorted(os.listdir(PLANS))
    except OSError:
        return out
    for name in names:
        if not name.endswith(".plan.md"):
            continue
        try:
            with open(os.path.join(PLANS, name), encoding="utf-8") as fh:
                text = fh.read()
        except OSError:
            continue
        m = FRONT.search(text)
        # steps live under '## Steps'; count there, not in the head
        sec = text.split("## Steps", 1)
        sec = sec[1].split("\n## ", 1)[0] if len(sec) > 1 else ""
        steps = len(re.findall(r"(?m)^- \[[ x]\]", sec))
        done = len(re.findall(r"(?m)^- \[x\]", sec))
        out.append({
            "slug": name[:-len(".plan.md")],
            "status": m.group(1) if m else "proposed",
            "risk": m.group(2) if m else "normal",
            "accepted": m.group(3) if m else "-",
            "steps_total": steps,
            "steps_done": done,
        })
    return out


def main():
    try:
        plans = read_plans()
        feed = {"generated": __import__("datetime").datetime.now(
            __import__("datetime").timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "queue_next": queue_next(),
            "last_ceremony_commit": last_ceremony(),
            "plans": plans}
        # per-PID tmp — never share a tmp across processes (see sessions-feed.py)
        tmp = "%s.%d.tmp" % (OUT, os.getpid())
        with open(tmp, "w", encoding="utf-8") as fh:
            json.dump(feed, fh, indent=1)
        os.replace(tmp, OUT)
        print("plan-feed: %d plan(s)" % len(plans))
    except Exception as exc:  # fail-closed: keep the old feed
        print("plan-feed: %s" % exc, file=sys.stderr)
    sys.exit(0)


if __name__ == "__main__":
    main()
