#!/usr/bin/env python3
"""router-tick — route one alert occurrence to a plan candidate.

Implements the "Outcome tracking without kernel changes (2026-08-31)"
contract (hngh docs/research/2026-08-30-alert-to-work-routing-patterns-
closing-the-self-observation-loop.md, fields 1/2/6):

- pre-check before any report-queue --add: the same two greps the
  overnight selector uses (status=accepted front-matter, an unchecked
  `- [ ]` step); when the identity's named step is closed, skip the
  candidate add and file exactly one observable pair — a STATE.md
  breadcrumb `router | duplicate-skip | <identity> step already closed`
  plus a deduped alert row --identity router:dup-skip:<identity>
  --window 86400 (this is router-rearm-precheck's parked "one
  closed-step re-fire is demonstrably skipped");
- first fire (identity names no plan): check the plans dir for an
  existing routed plan with the same subject slug (any date prefix)
  that is non-terminal (not executed/rejected) and younger than the
  dedup window (HNGH_ROUTER_DEDUP_HOURS, default 12h). A live
  duplicate suppresses the candidate — the plan queue stays clean
  while the alert row still lands in reports.md — and counts the
  suppression in a STATE.md `router | plan-dedup` crumb; >=3 dedups
  in one day escalate a row to operator visibility once/day
  (loop-recognition lesson: a stuck loop must be visible, not
  silently swallowed). Terminal or window-aged candidates route
  fresh (suffixed slug, never an overwrite).
- first fire with no live duplicate: draft a routed candidate — a
  status=proposed plan file, front-matter tagged routed-from=<identity>
  (both parsers tolerate the trailing attribute: accept-plans.py:32-33,
  jobs/plan-feed.py:21-22) — and file the routed-at progress row
  --identity router:routed:<slug> --window 86400;
- critical classes park with an operator-facing alert, never a candidate.

Identity grammar (routing doc, thread 2): <class>[:...]:plan:<slug>[:step-N]
names a plan step; anything else is a first fire. No router-internal
state: the skip decision is re-derived from the plan file each run.
"""
import os
import re
import subprocess
import sys
import tempfile
import time
from datetime import datetime, timezone

KERNEL = os.environ.get(
    "HNGH_HOME", os.path.expanduser("~/Projects/etc/hngh"))
AUTOMATION = os.environ.get(
    "HNGH_AUTOMATION_ROOT",
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PLANS = os.path.join(KERNEL, "docs", "project", "plans")
STATE_FILE = os.environ.get("STATE_FILE", os.path.join(AUTOMATION, "STATE.md"))
REPORT_QUEUE = os.environ.get(
    "HNGH_REPORT_QUEUE", os.path.join(KERNEL, "scripts", "report-queue"))
REPORT_ROOT = os.environ.get("HNGH_REPORT_ROOT", KERNEL)

IDENT_OK = re.compile(r"^[A-Za-z0-9._:-]+$")
STEP_SUFFIX = re.compile(r":step-(\d+)$")
# routing table (routing doc "Recommendation"): class key -> candidate shape
CRITICAL_KEYS = ("remote-posture", "budget")
NORMAL_SHAPES = [
    ("gate", ("Re-run the named gate, capture the failing check, fix or park",
              "both `make test` gates green; failing check captured")),
    ("tree-skew", ("Whitelist check + handoff/commit of the stalled edit",
                   "dirty-tree whitelist clean; stalled edit committed or handed off")),
    (("agent-stall", "loop-signal"),
     ("Stop the stalled session, write a handoff brief (last state + next "
      "action), start the replacement",
      "old session id gone from supervision state; handoff brief file "
      "exists; replacement session shows fresh tool activity")),
    (("ceremony-temp", "store"),
     ("Re-run the ceremony with a fresh per-run store (known recovery)",
      "ceremony completes rc=0 from a fresh /tmp/hngh-cer-* store")),
    ("review", ("Fix the review finding in docs/automation with a named verification",
                "the finding's own check passes; `make test` green")),
    ("readout", ("Feed-regen re-read step (fix already landed as precedent)",
                 "readout.json regenerates and parses")),
]
TERMINAL_STATUS = ("executed", "rejected")


def now_utc():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def breadcrumb(job, event, detail):
    """STATE.md row in the lib/breadcrumbs.sh 4-field format."""
    if os.environ.get("DRY_RUN") == "1":
        print("[dry-run] crumb %s|%s|%s" % (job, event, detail))
        return
    detail = detail.replace("|", "¦")
    line = "%s | %s | %s | %s\n" % (now_utc(), job, event, detail)
    os.makedirs(os.path.dirname(STATE_FILE) or ".", exist_ok=True)
    with open(STATE_FILE, "a", encoding="utf-8") as fh:
        fh.write(line)


def report(kind, text, ident, window):
    """File one report-queue row; a lost row must not block the tick."""
    if os.environ.get("DRY_RUN") == "1":
        print("[dry-run] row %s|%s|%s|%s" % (kind, text, ident, window))
        return
    try:
        subprocess.run(
            [REPORT_QUEUE, "--add", kind, text,
             "--identity", ident, "--window", str(window)],
            env={**os.environ, "HNGH_REPORT_ROOT": REPORT_ROOT},
            capture_output=True, timeout=30)
    except Exception:
        pass


def dedup_window_s():
    """Dedup window seconds: HNGH_ROUTER_DEDUP_HOURS (default 12h)."""
    try:
        return abs(float(os.environ.get("HNGH_ROUTER_DEDUP_HOURS", "12"))) \
            * 3600.0
    except ValueError:
        return 12 * 3600.0


def plan_status_age(path):
    """(status, age_seconds) for a plan file; (None, None) unreadable."""
    try:
        with open(path, encoding="utf-8") as fh:
            m = re.search(r"status=(\w+)", fh.read(400))
        return ((m.group(1) if m else None),
                max(0.0, time.time() - os.path.getmtime(path)))
    except OSError:
        return None, None


def live_duplicate(identity, window_s):
    """Newest routed plan for this subject (any route suffix -N, across
    all date prefixes) that is non-terminal AND younger than window_s,
    else None — a duplicate candidate would only re-pollute the plan
    queue."""
    ident = re.sub(r"[^A-Za-z0-9._-]+", "-", identity)
    dup_re = re.compile(r"^\d{4}-\d{2}-\d{2}-routed-%s(-\d+)?\.plan\.md$"
                        % re.escape(ident))
    best = None
    try:
        names = os.listdir(PLANS)
    except OSError:
        return None
    for name in names:
        if not dup_re.match(name):
            continue
        path = os.path.join(PLANS, name)
        status, age = plan_status_age(path)
        if status in TERMINAL_STATUS or age is None or age >= window_s:
            continue  # terminal or window-aged: the alert routes fresh
        if best is None or age < best[1]:
            best = (name[:-8], age)
    return best


def dedup_count_today(identity):
    """Dedup occurrences for this identity today, including the one being
    decided — STATE.md crumbs are the only counter (no router-internal
    state; the skip decision re-derives from files each run)."""
    today = now_utc()[:10]
    n = 1
    try:
        with open(STATE_FILE, encoding="utf-8") as fh:
            for line in fh:
                if (line.startswith(today) and "plan-dedup" in line
                        and identity in line):
                    n += 1
    except OSError:
        pass
    return n


def escalate_n():
    """Occurrence threshold before a zero-progress plan parks: env
    HNGH_ROUTER_ESCALATE_N, then the cadence-params.tsv inventory row,
    else 3 (same env->tsv->default pattern as jobs/research-feed.py)."""
    v = os.environ.get("HNGH_ROUTER_ESCALATE_N")
    if not v:
        try:
            with open(os.path.join(AUTOMATION, "cadence-params.tsv"),
                      encoding="utf-8") as fh:
                for line in fh:
                    if line.startswith("#"):
                        continue
                    parts = line.rstrip("\n").split("\t")
                    if len(parts) > 1 and parts[0] == "router-escalate-n":
                        v = parts[1]
                        break
        except OSError:
            pass
    try:
        return max(1, int(float(v)))
    except (TypeError, ValueError):
        return 3


def occurrence_count(text):
    """Distinct occurrence lines in the plan's `## Occurrences`
    escalation record (0 when the section is absent)."""
    sec = text.split("## Occurrences", 1)
    sec = sec[1].split("\n## ", 1)[0] if len(sec) > 1 else ""
    return len(re.findall(r"(?m)^- ", sec))


def bump_occurrences(path, text):
    """Append one occurrence line to the plan's `## Occurrences`
    section (created at the end of the file when absent); atomic.
    mtime is preserved: the dedup window ages on original routing
    time, recurrences live in the occurrence timestamps."""
    st = os.stat(path)
    line = "- %s re-occurred (dedup window expired)" % now_utc()
    if "## Occurrences" in text:
        head, rest = text.split("## Occurrences", 1)
        nxt = rest.split("\n## ", 1)
        tail = nxt[0].rstrip("\n") + "\n" + line + "\n"
        if len(nxt) > 1:
            tail += "\n## " + nxt[1]
        new = head + "## Occurrences" + tail
    else:
        new = text.rstrip("\n") + "\n\n## Occurrences\n\n" + line + "\n"
    tmp = tempfile.NamedTemporaryFile("w", delete=False, dir=PLANS,
                                      suffix=".tmp", encoding="utf-8")
    tmp.write(new)
    tmp.close()
    os.replace(tmp.name, path)
    os.utime(path, (st.st_atime, st.st_mtime))


def step_states(text):
    """(closed, open) counts of `## Steps` checkbox lines."""
    sec = text.split("## Steps", 1)
    sec = sec[1].split("\n## ", 1)[0] if len(sec) > 1 else ""
    starts = re.findall(r"(?m)^- \[[ x]\]", sec)
    return (starts.count("- [x]"), starts.count("- [ ]"))


def named_step_closed(text, n):
    """True when step n (1-based) exists and is `- [x]`."""
    sec = text.split("## Steps", 1)
    sec = sec[1].split("\n## ", 1)[0] if len(sec) > 1 else ""
    starts = [ln for ln in sec.splitlines()
              if ln.startswith("- [ ]") or ln.startswith("- [x]")]
    return 0 < n <= len(starts) and starts[n - 1].startswith("- [x]")


def shape_for(identity):
    """Routing-table candidate shape for an alert identity."""
    low = identity.lower()
    if any(k in low for k in CRITICAL_KEYS):
        return None  # critical parks, per the plan contract
    for keys, shape in NORMAL_SHAPES:
        if isinstance(keys, str):
            keys = (keys,)
        if any(k in low for k in keys):
            # knowledge-shaped: re-running the gate without new knowledge
            # just loops; route to research first (disposition spine)
            if keys == ("gate",) and "tree-skew" not in low:
                return research_shape(identity)
            return shape
    # plan-draft-fail and the generic investigate fallthrough are
    # knowledge-shaped too
    return research_shape(identity)


def research_shape(identity):
    """Research-demand candidate: one Delve step that opens a research
    subject for the alert identity, records its disposition, then fixes
    or parks. The subject id follows the fail-YYYYMMDD-<slug> bestiary
    convention so the session can append it to research-subjects.txt."""
    slug = re.sub(r"[^a-z0-9._-]+", "-", identity.lower()).strip("-")
    sid = "fail-%s-%s" % (now_utc()[:10].replace("-", ""), slug)
    return (
        "Delve: open research subject %s for %s; record disposition; "
        "then fix or park" % (sid, identity),
        "research subject %s present in research-subjects.txt with a "
        "recorded disposition; alert fixed or parked" % sid)


def candidate_text(identity, text, shape, date):
    title, verify = shape
    body = text if text else identity
    return (
        "<!-- plan: status=proposed risk=normal accepted=- "
        "routed-from=%s -->\n"
        "# %s — routed candidate\n"
        "\n"
        "Routed by scripts/router-tick.py from alert identity `%s`\n"
        "at %s. Alert text: %s\n"
        "\n"
        "## Steps\n"
        "\n"
        "- [ ] %s\n"
        "      Verification: %s\n" % (identity, date, identity, now_utc(), body,
                                     title, verify))


def route(identity, text):
    """One alert occurrence -> candidate / dedup / skip pair.
    Returns exit code."""
    if not IDENT_OK.match(identity):
        breadcrumb("router", "no-candidate", "%s identity not routable" % identity)
        return 0
    if ":plan:" in identity:
        return refire(identity)
    shape = shape_for(identity)
    date = now_utc()[:10]
    slug = "%s-routed-%s" % (date, re.sub(r"[^A-Za-z0-9._-]+", "-", identity))
    if shape is None:  # critical-class: parks, never a machine candidate
        report("alert", "router parks critical-class alert %s for the "
               "operator (candidate never machine-drafted)" % identity,
               "router:parked:%s" % identity, 604800)
        breadcrumb("router", "parked", "%s critical-class parks" % identity)
        return 0
    dup = live_duplicate(identity, dedup_window_s())
    if dup:
        # keep the signal (alert row still lands in reports.md), keep
        # the plan queue clean; >=3 dedups in a day escalate once/day
        dup_slug, age = dup
        dup_path = os.path.join(PLANS, dup_slug + ".plan.md")
        try:
            with open(dup_path, encoding="utf-8") as fh:
                dup_text = fh.read()
        except OSError:
            dup_text = ""
        status = re.search(r"status=(\w+)", dup_text[:400])
        status = status.group(1) if status else "proposed"
        closed_ct, _ = step_states(dup_text)
        # an accepted plan with closed steps is execution supply, not a
        # routing duplicate: leave it alone (refire() owns its steps);
        # only zero-progress candidates accumulate toward the park
        in_progress = status == "accepted" and closed_ct > 0
        disposed = None
        if not in_progress and os.environ.get("DRY_RUN") != "1":
            bump_occurrences(dup_path, dup_text)
            with open(dup_path, encoding="utf-8") as fh:
                occurrences = occurrence_count(fh.read())
            if occurrences >= escalate_n():
                disposed = subprocess.run(
                    [sys.executable,
                     os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                  "plan-dispose.py"),
                     dup_path, "--action", "park", "--cause", "obsolete",
                     "--reason", "identity re-occurred %d times without "
                     "landing; operator escalation stands" % occurrences],
                    env={**os.environ}, capture_output=True, timeout=30)
        count = dedup_count_today(identity)
        report("alert", "router dedup: %s suppressed (routed candidate %s "
               "still live, %dh old; day count %d)"
               % (identity, dup_slug, int(age // 3600), count),
               "router:dedup:%s" % identity, 86400)
        if count >= 3:
            report("alert", "router dedup escalation: %s recurring — "
                   "suppressed %d times today — escalated to operator "
                   "visibility" % (identity, count),
                   "router:dedup-escalated:%s" % identity, 86400)
        breadcrumb("router", "plan-dedup",
                   "%s suppressed (%s live, %dh old); day count %d"
                   % (identity, dup_slug, int(age // 3600), count))
        if disposed is not None and disposed.returncode == 0:
            report("alert", "router escalated: %s re-occurred %d times "
                   "without landing — plan %s parked (cause=obsolete); "
                   "operator disposition stands" % (identity, occurrences,
                                                    dup_slug),
                   "router:parked:%s" % identity, 604800)
            breadcrumb("router", "escalated-park",
                       "%s -> %s parked after %d occurrences"
                       % (identity, dup_slug, occurrences))
        return 0
    path = os.path.join(PLANS, slug + ".plan.md")
    if os.path.exists(path):
        # window-aged same-day plan routes fresh: suffix, never overwrite
        n = 2
        while os.path.exists(os.path.join(
                PLANS, "%s-%d.plan.md" % (slug, n))):
            n += 1
        path = os.path.join(PLANS, "%s-%d.plan.md" % (slug, n))
        slug = os.path.basename(path)[:-8]
    os.makedirs(PLANS, exist_ok=True)
    if os.environ.get("DRY_RUN") == "1":
        print("[dry-run] would draft candidate %s from %s" % (path, identity))
        return 0
    tmp = tempfile.NamedTemporaryFile("w", delete=False, dir=PLANS,
                                       suffix=".tmp", encoding="utf-8")
    tmp.write(candidate_text(identity, text, shape, date))
    tmp.close()
    os.replace(tmp.name, path)
    report("progress", "router routed %s -> plan candidate %s (routed-at %s)"
           % (identity, slug, now_utc()), "router:routed:%s" % slug, 86400)
    breadcrumb("router", "routed", "%s -> %s" % (identity, slug))
    return 0


def refire(identity):
    """Pre-check plan state before any add; skip when the step is closed."""
    _, rest = identity.split(":plan:", 1)
    m = STEP_SUFFIX.search(rest)
    slug, step = (rest[:m.start()], int(m.group(1))) if m else (rest, None)
    path = os.path.join(PLANS, slug + ".plan.md")
    if not os.path.isfile(path):
        breadcrumb("router", "no-candidate", "%s names no plan file" % identity)
        return 0
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    closed_ct, open_ct = step_states(text)
    # the named step is open when it exists unchecked, or (no step
    # number) any `- [ ]` remains — the selector's grep, read directly
    still_open = (not named_step_closed(text, step) if step
                  and step <= closed_ct + open_ct else open_ct > 0)
    if still_open:
        # named step still open: the work is scheduled, no candidate re-draft
        report("progress", "router re-fire of %s (named step still open)"
               % identity, "router:routed:%s%s" %
               (slug, ":step-%d" % step if step else ""), 86400)
        breadcrumb("router", "in-flight", "%s step still open" % identity)
        return 0
    # named step closed (or nothing left): the re-fire is a duplicate —
    # skip the candidate add, file exactly one observable skip pair
    report("alert", "router duplicate-skip: %s (named step closed; "
           "candidate not re-drafted)" % identity,
           "router:dup-skip:%s" % identity, 86400)
    breadcrumb("router", "duplicate-skip", "%s step already closed" % identity)
    return 0


def main():
    args = sys.argv[1:]
    identity = None
    text = ""
    i = 0
    while i < len(args):
        if args[i] == "--identity" and i + 1 < len(args):
            identity = args[i + 1]
            i += 2
        elif args[i] == "--text" and i + 1 < len(args):
            text = args[i + 1]
            i += 2
        else:
            print("usage: router-tick.py --identity ID [--text TEXT]",
                  file=sys.stderr)
            return 2
    if not identity:
        print("usage: router-tick.py --identity ID [--text TEXT]", file=sys.stderr)
        return 2
    return route(identity, text)


if __name__ == "__main__":
    sys.exit(main())
