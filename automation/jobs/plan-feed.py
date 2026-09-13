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

# Optional front-matter keys, extracted independently of FRONT so the
# legacy status/risk/accepted parsing stays byte-compatible (plans
# carrying priority= before accepted= still parse exactly as before:
# no summary field changes, no invented defaults).
PRIO = re.compile(r"\bpriority=(\w+)")
CAUSE = re.compile(r"\bcause=([\w-]+)")
COMMENT = re.compile(r"<!--\s*plan:[^>]*-->")

# Work-graph edge vocabulary: edges come ONLY from execution-notes
# lines matching this fixed convention ("- Step N unlocks Step M" /
# "- Step N feeds Step M"). Prose that does not match emits no edge --
# blocked-by is drawn only from real evidence, never invented.
EDGE = re.compile(r"^\s*[-*]\s*Step\s+(\d+)\s+(unlocks|feeds)\s+"
                  r"[Ss]tep\s+(\d+)\s*\.?\s*$", re.M)

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


def _sections(text):
    """Get a `## Title` section body (until the next top-level `## ")."""
    def body(title):
        parts = text.split("## " + title, 1)
        return parts[1].split("\n## ", 1)[0] if len(parts) > 1 else ""
    return body


def _work_graph(text):
    """Parse the work graph for one plan: (steps, edges). Raises on
    malformed input -- the caller isolates the fault per plan and
    keeps the legacy summary fields intact."""
    body = _sections(text)
    steps = []
    cur = None
    for line in body("Steps").splitlines():
        m = re.match(r"^- \[([^\]]*)\] ?(.*)$", line)
        if m is not None:
            box, title = m.group(1), m.group(2).strip()
            if box not in (" ", "", "x", "X"):
                raise ValueError("malformed checkbox marker [" + box + "]")
            title = re.sub(r"^\d+[.:]\s*", "", title)
            title = re.sub(r"^\w{1,20}:\s*", "", title)
            cur = {"n": len(steps) + 1, "title": title,
                   "done": box.lower() == "x", "verification": ""}
            steps.append(cur)
        elif cur is not None and line[:1].isspace():
            cur["verification"] = (cur["verification"] + " "
                                   + line.strip()).strip()
    for step in steps:
        m = re.search(r"Verification:\s*(.*)", step["verification"])
        step["verification"] = (m.group(1).strip().rstrip(".")
                                if m else "")
    edges = [
        {"type": etype, "from": int(src), "to": int(dst)}
        for src, etype, dst in EDGE.findall(body("Execution notes"))]
    return steps, edges


def read_plans():
    out, alerts = [], []
    try:
        names = sorted(os.listdir(PLANS))
    except OSError:
        return out, alerts
    for name in names:
        if not name.endswith(".plan.md"):
            continue
        slug = name[:-len(".plan.md")]
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
        front = COMMENT.search(text)
        front_text = front.group(0) if front else ""
        prio, cm = PRIO.search(front_text), CAUSE.search(front_text)
        priority = prio.group(1) if prio else None
        cause = cm.group(1) if cm else None
        try:
            graph_steps, edges = _work_graph(text)
            if cause and (m.group(1) if m else "proposed") == "parked":
                edges = (edges + [{"type": "parked-because",
                                   "cause": cause, "from": None,
                                   "to": None}])
            parse_error = None
        except Exception as exc:
            # per-plan failure isolation: the legacy summary fields
            # still emit; the graph fails closed with an alert row
            graph_steps, edges, parse_error = [], [], "%s: %s" % (
                type(exc).__name__, exc)
            alerts.append({"slug": slug, "detail": parse_error})
        plan = {
            "slug": slug,
            "status": m.group(1) if m else "proposed",
            "risk": m.group(2) if m else "normal",
            "accepted": m.group(3) if m else "-",
            "steps_total": steps,
            "steps_done": done,
            "priority": priority,
            "cause": cause,
            "steps": graph_steps,
            "edges": edges,
        }
        if parse_error:
            plan["parse_error"] = True
        out.append(plan)
    return out, alerts


def main():
    try:
        plans, alerts = read_plans()
        feed = {"generated": __import__("datetime").datetime.now(
            __import__("datetime").timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "queue_next": queue_next(),
            "last_ceremony_commit": last_ceremony(),
            "alerts": alerts,
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
