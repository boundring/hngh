#!/usr/bin/env python3
"""patrol -- the formal rounds (2026-09-12, operator directive "rounds
and patrols"). The ad-hoc night-watch loop (45m wakes over STATE crumbs,
handoffs, blockers, gate, budget, digest QA) becomes a standing patrol:
one runner walks a structured checklist of surfaces from
config/patrol-routes.tsv, each check a deterministic pure function over
existing ledgers (no model calls), and files structured findings.

Surfaces the night-watch director session used to eyeball, now checks:
dashboard feed staleness, blocker ledger escalations, handoff
dead/cancelled accumulation, gate crumbs, overnight stall crumbs, the
loop-history guard rc, research-line flow, the paper edition (daily
digest), companion-service health, disk, and the session budget.

The gate-cure route (2026-09-13) adds the red-gate self-cure: on
kernel-gate-red detection the violating commits are declared post-hoc
and the ceremony is driven from the patrol itself (the SMALL-matter
amendment, docs/design/autonomous-development-control.md).

Machine contract (mirrors jobs/publication-review.py): stdout carries one
`PASS <patrol>/<check> <detail>` or `FAIL <patrol>/<artifact> <cause>
<detail>` line per check; FAILs file report-queue alerts (identity
patrol:<id>) and append to automation/digest/PATROL-<date>.md (supportive
+ adversarial sections, the publication-review two-pass format). A
patrol+cause pair repeating on two consecutive runs auto-queues a
research-subjects entry (house convention, cadence/hour/33-research-beat.sh
followon_queue): the patrol found the pattern, the research beat
crystallizes the lesson.

Fail-first on the patrol itself: a runner crash files one alert and exits
0 (a crumb, never tick damage); a single check crash fails open as a
`check-crash` FAIL and the remaining checks still run. Only usage errors
exit 2.

usage: jobs/patrol.py [--patrol ID | --tier TIER | --all] [--repo DIR]
              [--kernel DIR] [--report-root DIR] [--date YYYY-MM-DD]
"""
import argparse
import importlib.util
import json
import os
import shutil
import re
import subprocess
import sys
import tempfile
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)  # automation/
REPO = os.path.dirname(ROOT)  # the hngh repo (kernel home)

# one identity seam for every digest writer (writer census 2026-09-16;
# seam consolidated into lib/scrub.py 2026-09-16): scrub_paths imported
# from the shared module so the findings doc and the morning rounds
# block cannot drift from the mega-line guard
sys.path.insert(0, os.path.join(ROOT, "lib"))
from scrub import scrub_paths

FEEDS = [("plans.json", 3600), ("operator-items.json", 600),
         ("sessions.json", 600),  # tier-scaled: 30m feed vs 1m feeds
         ("research-routes.json", 28800)]  # build-on-demand d6 feed: 8h
LESSONS_STALE_HOURS = 6  # disposition landing -> harvest refresh budget
HANDOFFS_LAST_N = 10
HANDOFFS_THRESHOLD = 3
GATE_STALE_HOURS = 26  # the day gate runs once a day; 24h + one tier slack
GATE_CRUMB_TTL_S = 86400  # a crumb older than this is not gate evidence
DISK_PCT = 90
RESEARCH_STALL_HOURS = 48
STUCK_STATES = ("planned", "expanding", "contracting")
FEEDBACK_FLOOD = 20  # unprocessed dashboard feedback json backlog cap
MANGA_STALE_HOURS = 48  # newest draft older than this = pipeline stalled
ROADMAP_STALE_DAYS = 14  # landing stage without movement this long fires
ROADMAP_HISTORY_DAYS = 30  # movement older than this is not fresh evidence
ROTATION_DUE_DAYS = 7  # queue Next item held this long fires rotation-due

def _manga_dir(root):
    """Working manga dir: the hngh home manga dir when it exists (the
    pipeline's default output since 2026-09-13), else the repo's
    committed docs/media/manga."""
    home = os.environ.get("HNGH_HOME_DIR") or \
        os.path.join(os.path.expanduser("~"), ".hngh")
    work = os.path.join(home, "manga")
    return work if os.path.isdir(work) else \
        os.path.join(os.path.dirname(root), "docs", "media", "manga")
DECK_ITEM_RE = re.compile(r"^(CRITICAL|NOTABLE|CONTEXT):")
DECK_BLOCK_RE = re.compile(r"^## \d{4}\b")


def _email_tail(ctx):
    """notify-email.log bytes written SINCE the previous patrol run,
    via a byte watermark persisted next to the log. First run after a
    cold start baselines at the current size: the log's history is
    old news, not a finding (2026-09-13 — counting the whole UTC day
    re-fired stale 16:24Z failures for hours; bcf6956b). A truncated/
    rotated log reads as all-new, fail open."""
    log = ctx["email_log"]
    mark = os.environ.get("PATROL_EMAIL_MARK", log + ".mark")
    try:
        size = os.path.getsize(log)
    except OSError:
        return []  # no log: the channel is dormant, nothing new
    try:
        start = int(open(mark, encoding="utf-8").read().strip())
    except (OSError, ValueError):
        start = size  # no watermark yet: baseline, skip history
    if start > size:
        start = 0
    tail = []
    if start < size:
        with open(log, encoding="utf-8", errors="replace") as fh:
            fh.seek(start)
            tail = fh.read().splitlines()
    try:
        with open(mark, "w", encoding="utf-8") as fh:
            fh.write(str(size))
    except OSError:
        pass  # lost mark = next run re-baselines, never a crash
    return tail


def get_param(params_path, key, default):
    """cadence-params.tsv row value (fail-open to the default)."""
    try:
        with open(params_path, encoding="utf-8", errors="replace") as fh:
            for ln in fh:
                f = ln.rstrip("\n").split("\t")
                if f and f[0] == key and len(f) > 1 and f[1]:
                    return f[1]
    except OSError:
        pass
    return str(default)


def ts_epoch(s):
    """ISO UTC timestamp -> epoch seconds, or None."""
    try:
        return time.mktime(time.strptime(s, "%Y-%m-%dT%H:%M:%SZ")) - time.timezone
    except (ValueError, TypeError):
        return None


def crumbs(state_text, job=None, events=None):
    """[(epoch, event, detail)] from STATE.md breadcrumb lines, oldest
    first, optionally filtered to one job and a set of events."""
    out = []
    for ln in state_text.splitlines():
        parts = ln.split(" | ")
        if len(parts) != 4:
            continue
        if job and parts[1].strip() != job:
            continue
        if events and parts[2].strip() not in events:
            continue
        e = ts_epoch(parts[0].strip())
        if e is not None:
            out.append((e, parts[2].strip(), parts[3].strip()))
    return out


def check_feed_freshness(ctx):
    """Dashboard feeds: mtime staleness per feed tier (30m plans feed vs
    the 1m sessions/operator-items feeds)."""
    out = {"passes": [], "fails": []}
    now = ctx["now"]
    for name, stale_s in FEEDS:
        path = os.path.join(ctx["root"], "dashboard", name)
        try:
            age = now - os.path.getmtime(path)
        except OSError:
            out["fails"].append((name, "feed-missing", "no feed file"))
            continue
        if age > stale_s:
            out["fails"].append((name, "feed-stale",
                                 "age=%ds > %ds" % (age, stale_s)))
        else:
            out["passes"].append(("feed-freshness:" + name,
                                  "age=%ds" % age))
    out["fails"] = [("dashboard/" + n, c, d) for (n, c, d) in out["fails"]]
    return out


def check_blocker_escalations(ctx):
    """Blocker ledger: an ACTIVE row at/over blocker-escalate-n attempts
    means the watchdog failed to park it; parked rows are the escalation
    path working (reported, not failed)."""
    out = {"passes": [], "fails": []}
    escalate_n = int(get_param(ctx["params"], "blocker-escalate-n", 2))
    parked = active = 0
    try:
        with open(ctx["blockers"], encoding="utf-8", errors="replace") as fh:
            for ln in fh:
                f = ln.rstrip("\n").split("\t")
                if len(f) < 6 or not f[1]:
                    continue
                try:
                    attempts = int(f[4])
                except ValueError:
                    continue
                if f[5] == "parked":
                    parked += 1
                elif attempts >= escalate_n:
                    out["fails"].append((f[1], "blocker-escalated",
                                         "attempts=%s >= %s, not yet parked"
                                         % (f[4], escalate_n)))
                else:
                    active += 1
    except OSError:
        out["passes"].append(("blocker-ledger", "no ledger (nothing blocked)"))
        return out
    out["passes"].append(("blocker-ledger",
                          "active=%d parked=%d escalate_n=%d"
                          % (active, parked, escalate_n)))
    return out


def trailing_failed_crumbs(state_text):
    """Consecutive `failed` tokens counting backwards across the
    overnight-done results= breadcrumbs (beat-watchdog rule a)."""
    n = 0
    for _, _, detail in reversed(crumbs(state_text,
                                        job="overnight-cycle.sh",
                                        events={"overnight-done"})):
        m = re.search(r"results=([\w,]*)", detail)
        for tok in reversed((m.group(1).split(",") if m else [])):
            if tok != "failed":
                return n
            n += 1
    return n


def check_stall_crumbs(ctx):
    """Overnight launch-plane stall: >= beat-stall-n consecutive `failed`
    results tokens in STATE.md (the 2026-09-11 signature)."""
    out = {"passes": [], "fails": []}
    stall_n = int(get_param(ctx["params"], "beat-stall-n", 3))
    try:
        with open(ctx["state"], encoding="utf-8", errors="replace") as fh:
            text = fh.read()
    except OSError:
        out["fails"].append(("STATE.md", "ledger-unreadable", "no STATE.md"))
        return out
    n = trailing_failed_crumbs(text)
    if n >= stall_n:
        out["fails"].append(("overnight", "bad-execution",
                             "trailing failed crumbs=%d >= %d" % (n, stall_n)))
    else:
        out["passes"].append(("stall-crumbs", "trailing failed=%d" % n))
    return out


def check_handoff_deaths(ctx):
    """Handoff accumulation: dead/cancelled runs among the last N
    overnight-lead rows (the accumulation signature a director session
    used to count by eye)."""
    out = {"passes": [], "fails": []}
    rows = []
    try:
        with open(ctx["handoffs"], encoding="utf-8", errors="replace") as fh:
            for ln in fh:
                if ln.startswith("overnight-lead |"):
                    rows.append(ln)
    except OSError:
        out["passes"].append(("handoffs-accumulation", "no handoff ledger"))
        return out
    tail = rows[-HANDOFFS_LAST_N:]
    dead = [ln for ln in tail
            if " dead " in ln or "cancelled" in ln]
    if len(dead) >= HANDOFFS_THRESHOLD:
        out["fails"].append(("agent-handoffs.md", "bad-execution",
                             "%d dead/cancelled in last %d rows"
                             % (len(dead), len(tail))))
    else:
        out["passes"].append(("handoffs-accumulation",
                              "%d dead/cancelled in last %d rows"
                              % (len(dead), len(tail))))
    return out


def check_gate_crumbs(ctx):
    """Automation gate by crumb, not by re-run: 03-gate-check.sh files
    gate-green/gate-red crumbs per label; the newest crumb within the
    freshness window (GATE_CRUMB_TTL_S, default 86400s, PATROL_GATE_
    CRUMB_TTL_S override) decides; a red or green crumb older than the
    TTL is not evidence of the current gate state, so it degrades to a
    single "gate-stale" fail (fail-closed: absent/unfresh evidence is
    the alert-worthy condition, and one stable identity dedups via the
    report path instead of streaming a stale red for hours). Crumb
    timestamps come from the STATE.md ledger lines the crumbs() parser
    reads, so no mtime fallback is needed. check_gate_cure does NOT
    share this crumb stream (it runs the guard script directly), so it
    needs no freshness handling of its own."""
    out = {"passes": [], "fails": []}
    label = ctx["gate_label"]
    ttl_s = float(os.environ.get("PATROL_GATE_CRUMB_TTL_S",
                                 GATE_CRUMB_TTL_S))
    try:
        with open(ctx["state"], encoding="utf-8", errors="replace") as fh:
            text = fh.read()
    except OSError:
        text = ""
    rows = [r for r in crumbs(text, job="03-gate-check.sh",
                              events={"gate-green", "gate-red"})
            if r[2].startswith(label + ":")]
    if not rows:
        out["fails"].append((label, "gate-stale", "no gate crumb found"))
        return out
    fresh = [r for r in rows if ctx["now"] - r[0] <= ttl_s]
    if not fresh:
        age_h = (ctx["now"] - rows[-1][0]) / 3600.0
        out["fails"].append((label, "gate-stale",
                             "newest gate crumb %.1fh old (> TTL %.0fs)"
                             % (age_h, ttl_s)))
        return out
    _, event, detail = fresh[-1]
    age_h = (ctx["now"] - fresh[-1][0]) / 3600.0
    if event == "gate-red":
        out["fails"].append((label, "gate-red", detail))
    elif age_h > GATE_STALE_HOURS:
        out["fails"].append((label, "gate-stale",
                             "newest gate crumb %.1fh old" % age_h))
    else:
        out["passes"].append(("gate-crumbs:" + label,
                              "%s, %.1fh old" % (detail, age_h)))
    return out


def check_paper_edition(ctx):
    """Paper edition: today's hourly digest exists, is non-empty, and
    carries Deck A blocks (hour headers with item lines). Before 02:00
    UTC the day has barely started -- green with a note."""
    out = {"passes": [], "fails": []}
    if ctx["now_struct"].tm_hour < 2:
        out["passes"].append(("paper-edition", "edition not yet due (< 02:00 UTC)"))
        return out
    path = os.path.join(ctx["digest_dir"], "%s.md" % ctx["date"])
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        out["fails"].append((ctx["date"] + ".md", "digest-missing",
                             "no daily digest at digest/%s.md" % ctx["date"]))
        return out
    blocks = sum(1 for ln in text.splitlines() if DECK_BLOCK_RE.match(ln))
    items = sum(1 for ln in text.splitlines() if DECK_ITEM_RE.match(ln))
    if not text.strip() or blocks == 0:
        out["fails"].append(("digest/%s.md" % ctx["date"], "digest-empty",
                             "0 Deck A blocks"))
    elif items == 0:
        out["fails"].append(("digest/%s.md" % ctx["date"], "deck-a-empty",
                             "%d blocks, 0 items" % blocks))
    else:
        out["passes"].append(("paper-edition", "%d blocks, %d items"
                              % (blocks, items)))
    return out


def check_service_health(ctx):
    """Companion services: one HTTP probe per in-use/operator-run row
    with a health-url in config/hngh-services.tsv. Any HTTP answer is a
    responsive service (the deck-probe convention); transport failure is
    service-down."""
    out = {"passes": [], "fails": []}
    try:
        with open(ctx["services_tsv"], encoding="utf-8",
                  errors="replace") as fh:
            rows = [ln.rstrip("\n").split("\t")
                    for ln in fh if not ln.startswith("#")]
    except OSError:
        out["passes"].append(("service-health", "no services registry"))
        return out
    for f in rows:
        if len(f) < 8 or f[0] == "service":
            continue
        svc, url, disp = f[0], f[5], f[7]
        if disp not in ("in-use", "operator-run") or not url:
            continue
        try:
            urllib.request.urlopen(url, timeout=3).read(64)
            out["passes"].append(("service-health:" + svc,
                                  "%s responsive" % url))
        except urllib.error.HTTPError:
            out["passes"].append(("service-health:" + svc,
                                  "%s answered HTTP (error status)" % url))
        except Exception as exc:  # noqa: BLE001 -- down is a finding
            out["fails"].append((svc, "service-down",
                                 "%s unreachable: %s" % (url, exc.__class__.__name__)))
    return out


def check_disk_usage(ctx):
    """Disk: df use% over the threshold on /."""
    out = {"passes": [], "fails": []}
    try:
        df = subprocess.run(["df", "-P", "/"], capture_output=True,
                            text=True, timeout=15).stdout.splitlines()
        use = int(df[-1].split()[4].rstrip("%"))
    except (OSError, IndexError, ValueError, subprocess.SubprocessError):
        out["fails"].append(("/", "check-crash", "df unreadable"))
        return out
    if use >= DISK_PCT:
        out["fails"].append(("/", "disk-full", "use=%d%% >= %d%%"
                             % (use, DISK_PCT)))
    else:
        out["passes"].append(("disk-usage", "use=%d%%" % use))
    return out


GH_CI_RUNS_URL = ("https://api.github.com/repos/boundring/hngh"
                  "/actions/runs?per_page=1")


def check_github_ci(ctx):
    """Public CI settlement: the latest GitHub Actions run, read from
    the unauthenticated API (no token in the patrol). Quiet on success
    and on pending runs; FAIL when the latest completed run concluded
    non-success. URL seam HNGH_GH_CI_RUNS_URL (tests use file://)."""
    out = {"passes": [], "fails": []}
    url = os.environ.get("HNGH_GH_CI_RUNS_URL", GH_CI_RUNS_URL)
    try:
        with urllib.request.urlopen(url, timeout=10) as resp:
            runs = json.loads(resp.read(65536)).get("workflow_runs") or []
    except Exception as exc:  # noqa: BLE001 -- unreachable is a finding
        out["fails"].append(("github-actions-latest", "service-down",
                             "ci poll unreachable: %s"
                             % exc.__class__.__name__))
        return out
    if not runs:
        out["passes"].append(("github-actions-latest", "no runs yet"))
        return out
    run = runs[0]
    sha = (run.get("head_sha") or "?")[:7]
    status = run.get("status") or "?"
    if status != "completed":
        out["passes"].append(("github-actions-latest",
                              "%s status=%s (pending)" % (sha, status)))
    elif run.get("conclusion") == "success":
        out["passes"].append(("github-actions-latest", "%s success" % sha))
    else:
        out["fails"].append((
            "github-actions-latest", "bad-execution",
            "latest run %s concluded %s -- %s"
            % (sha, run.get("conclusion") or "?",
               run.get("html_url") or "no url")))
    return out


def check_research_stall(ctx):
    """Research flow: non-terminal lines stuck in one state longer than
    the stall window (a line that stops moving is a stopped line)."""
    out = {"passes": [], "fails": []}
    try:
        with open(ctx["research_lines"], encoding="utf-8",
                  errors="replace") as fh:
            rows = [ln.rstrip("\n").split("\t") for ln in fh
                    if not ln.startswith("#")]
    except OSError:
        out["passes"].append(("research-flow", "no research-lines.tsv"))
        return out
    stuck = 0
    for f in rows:
        if len(f) < 3:
            continue
        lid, state, ts = f[0], f[1], f[2]
        if state not in STUCK_STATES:
            continue
        e = ts_epoch(ts)
        if e is None:
            continue
        age_h = (ctx["now"] - e) / 3600.0
        if age_h > RESEARCH_STALL_HOURS:
            out["fails"].append((lid, "stalled-line",
                                 "state=%s for %.0fh" % (state, age_h)))
            stuck += 1
    out["passes"].append(("research-flow",
                          "%d line(s) stalled" % stuck if stuck
                          else "all lines moving"))
    return out


def check_research_ledger(ctx):
    """Lessons ledger (d1-harvest): research-lessons.tsv parses and its
    active rows stay consistent with the dispositions verdicts -- a
    retired-but-active lineage row, or a fresh adopted disposition with
    no matching fresh lesson row, means the harvest organ is dead and
    nothing else will notice."""
    out = {"passes": [], "fails": []}
    path = os.path.join(ctx["root"], "research-lessons.tsv")
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            raw = fh.read().splitlines()
    except OSError:
        out["fails"].append(("research-lessons.tsv", "ledger-missing",
                             "no research-lessons.tsv (harvest never ran?)"))
        return out
    header = ["lesson_id", "date", "line_id", "subject", "lesson", "status"]
    if raw and raw[0].split("\t") != header:
        out["fails"].append(("research-lessons.tsv", "header-drift",
                             "%r" % raw[0][:100]))
        return out
    active = {}
    for ln in raw[1:]:
        if not ln.strip():
            continue
        f = ln.split("\t")
        if len(f) != len(header) or not f[0]:
            out["fails"].append(("research-lessons.tsv", "row-malformed",
                                 "%r" % ln[:100]))
            continue
        if f[5] == "active":
            active[f[2]] = f
    # lineage: the newest disposition of an actively-harvested line must
    # still be adopted (non-adoption retires the row -- never outlives
    # the verdict), the harvest contract lib/research-harvest.py keeps
    disps = _disposition_actions(ctx["dispositions"])
    for lid, row in sorted(active.items()):
        action = disps.get(lid)
        if action is not None and action != "adopted":
            out["fails"].append(
                ("research-lessons.tsv", "lineage-contradiction",
                 "%s active but disposition %s" % (lid, action)))
    # freshness: a fresh adopted disposition needs a fresh lesson row
    # (the beat harvest runs at disposition landing; missed = dead organ)
    budget = LESSONS_STALE_HOURS * 3600
    missing = []
    for lid, epoch in _recent_adoptions(ctx["dispositions"], ctx["now"],
                                        budget):
        row = active.get(lid)
        e = ts_epoch(row[1]) if row else None
        if e is None or ctx["now"] - e > budget:
            missing.append(lid)
    if missing:
        out["fails"].append(
            ("research-lessons.tsv", "harvest-stale",
             "%d adopted disposition(s) in the last %.0fh without a fresh "
             "lesson row: %s" % (len(missing), LESSONS_STALE_HOURS,
                                 ", ".join(missing[:3]))))
    out["passes"].append(("research-ledger",
                          "%d active lesson(s), lineage ok" % len(active)
                          if not missing else "lineage ok, harvest stale"))
    return out


def _disposition_actions(path):
    """line_id -> newest known-action disposition (scan order wins; the
    harvest reads the same way). Unknown-action rows (e.g. 'fixed' from
    the blocker ledger) are skipped, matching the routes builder."""
    known = ("adopted", "parked", "killed")
    out = {}
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for ln in fh:
                if ln.startswith("#"):
                    continue
                f = ln.rstrip("\n").split("\t")
                if len(f) >= 2 and f[1] in known:
                    out[f[0]] = f[1]
    except OSError:
        pass
    return out


def _recent_adoptions(path, now, budget):
    """[(line_id, epoch)] of adopted dispositions inside the freshness
    budget (same newest-wins scan rule as _disposition_actions)."""
    out = {}
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            for ln in fh:
                if ln.startswith("#"):
                    continue
                f = ln.rstrip("\n").split("\t")
                if len(f) < 6 or f[1] != "adopted":
                    continue
                e = ts_epoch(f[5])
                if e is not None and now - e <= budget:
                    out[f[0]] = e
    except OSError:
        pass
    return list(out.items())


def check_session_budget(ctx):
    """Budget: today's delegated session runs in logs/budget.md against
    the sessions-day-max cap."""
    out = {"passes": [], "fails": []}
    cap = int(get_param(ctx["params"], "sessions-day-max", 200))
    n = 0
    try:
        with open(ctx["budget_log"], encoding="utf-8", errors="replace") as fh:
            for ln in fh:
                if ln.startswith(ctx["date"]) and " | session-run" in ln:
                    n += 1
    except OSError:
        pass  # no budget log: zero sessions today
    if n >= cap:
        out["fails"].append(("logs/budget.md", "budget",
                             "sessions=%d >= cap %d" % (n, cap)))
    else:
        out["passes"].append(("session-budget",
                              "sessions=%d cap=%d" % (n, cap)))
    return out


def check_loop_history_guard(ctx):
    """Kernel gate: the loop-history guard rc, run fresh (1-2s, git
    history only -- what the night-watch director checked by hand)."""
    out = {"passes": [], "fails": []}
    script = os.path.join(ctx["kernel"], "tests", "scripts",
                          "test-loop-history-guard.py")
    if not os.path.isfile(script):
        out["fails"].append(("kernel", "gate-stale", "guard script missing"))
        return out
    try:
        r = subprocess.run([sys.executable, script], cwd=ctx["kernel"],
                           capture_output=True, text=True, timeout=120)
    except subprocess.SubprocessError as exc:
        out["fails"].append(("kernel", "gate-red", "guard run fault: %s" % exc))
        return out
    last = (r.stdout.strip().splitlines() or [""])[-1]
    if r.returncode != 0:
        out["fails"].append(("kernel", "gate-red",
                             "guard rc=%d: %s" % (r.returncode, last)))
    else:
        out["passes"].append(("loop-history-guard", last or "rc=0"))
    return out


def guard_violations(kernel):
    """(rc, [violation sha...]) from a fresh loop-history guard run;
    rc None = the guard could not run (missing script or fault).
    Unreachable-exemption rows are excluded -- they need re-keying, not
    a new declaration."""
    script = os.path.join(kernel, "tests", "scripts",
                          "test-loop-history-guard.py")
    if not os.path.isfile(script):
        return None, []
    try:
        r = subprocess.run([sys.executable, script], cwd=kernel,
                           capture_output=True, text=True, timeout=120)
    except subprocess.SubprocessError:
        return None, []
    shas = []
    for ln in r.stdout.splitlines():
        m = re.match(r"^  ([0-9a-f]{7,40}) (.+)$", ln)
        if m and "exemption unreachable" not in m.group(2):
            shas.append(m.group(1))
    return r.returncode, shas


def patch_id(kernel, sha):
    """git patch-id --stable for sha (the purge-proof exemption key)."""
    try:
        show = subprocess.run(["git", "show", sha], cwd=kernel,
                              capture_output=True, text=True, check=True)
        pid = subprocess.run(["git", "patch-id", "--stable"], cwd=kernel,
                             input=show.stdout, capture_output=True,
                             text=True, check=True)
    except (subprocess.SubprocessError, OSError):
        return ""
    parts = pid.stdout.split()
    return parts[0] if parts else ""


def commit_subject(kernel, sha):
    try:
        r = subprocess.run(["git", "show", "-s", "--format=%s", sha],
                           cwd=kernel, capture_output=True, text=True,
                           check=True)
    except (subprocess.SubprocessError, OSError):
        return ""
    return r.stdout.strip()


def commit_numstat(kernel, sha):
    """[(additions, deletions, path)...] for sha (the LARGE-classifier
    input: pure deletions are visible only here, not in --name-only)."""
    try:
        r = subprocess.run(["git", "show", "--numstat", "--format=",
                            sha], cwd=kernel, capture_output=True,
                           text=True, check=True)
    except (subprocess.SubprocessError, OSError):
        return []
    rows = []
    for ln in r.stdout.splitlines():
        parts = ln.split("\t")
        if len(parts) >= 3 and parts[0].isdigit() and parts[1].isdigit():
            rows.append((int(parts[0]), int(parts[1]), parts[2]))
    return rows


# LARGE cure classes (docs/project/decisions.md, the 2026-09-13
# SMALL-matter amendment): never auto-declared by the gate-cure patrol.
_CRED_PATH_RE = re.compile(
    r"(^|/)(\.env(\..+)?|credentials?(\..+)?|secrets?(\..+)?|"
    r"tokens?(\..+)?|auth[_-]?token|\.?\w*\.pem)(/|$|\.)", re.I)
_SYSTEMD_SUFFIXES = (".service", ".timer", ".socket")
_SPEND_RE = re.compile(r"(spend|cost|budget|cap)", re.I)
_SPEND_CONFIG_PREFIX = "automation/config/"


def is_large_cure_violation(kernel, shas):
    """LARGE-surface pre-check: refuse the auto-declare when the
    violating commit set touches credential-like paths, systemd units,
    spend/cost/budget/cap configs under automation/config/, or any
    commit is a pure deletion (additions==0, deletions>0 -- a gutting
    commit). Returns a reason string, or "" when SMALL (auto-curable).
    The ceremony's own refusal stays the backstop; this pre-check keeps
    the refusal before the append, not after it."""
    for sha in shas:
        for additions, deletions, path in commit_numstat(kernel, sha):
            if additions == 0 and deletions > 0:
                return "pure-deletion diff (%s)" % sha
            norm = path.replace("\\", "/")
            if _CRED_PATH_RE.search(norm):
                return "credential-like path %s (%s)" % (path, sha)
            if norm.endswith(_SYSTEMD_SUFFIXES):
                return "systemd unit %s (%s)" % (path, sha)
            if (norm.startswith(_SPEND_CONFIG_PREFIX)
                    and _SPEND_RE.search(os.path.basename(norm))):
                return "spend/cost-cap config %s (%s)" % (path, sha)
    return ""


def append_exemptions(kernel, shas, date):
    """Register each sha in the guard's KNOWN_EXEMPTIONS table (hash +
    patch-id, the declaration precedent) and append the decisions.md
    batch entry. Returns a detail string, or "" on refusal (missing
    table, empty patch-id -- a refusal is the park, not a retry)."""
    guard_path = os.path.join(kernel, "tests", "scripts",
                              "test-loop-history-guard.py")
    decisions_path = os.path.join(kernel, "docs", "project", "decisions.md")
    try:
        with open(guard_path, encoding="utf-8") as fh:
            text = fh.read()
    except OSError:
        return ""
    try:
        idx = text.index("KNOWN_EXEMPTIONS = {")
        close = text.index("\n}", idx)
    except ValueError:
        return ""
    entries = []
    for sha in shas:
        pid = patch_id(kernel, sha)
        subject = commit_subject(kernel, sha)
        if not pid or not subject:
            return ""
        entries.append((sha, subject, pid))
    block = "".join(
        "    # %s -- kernel-gate red cure %s, declared not rewritten\n"
        "    \"%s\": {\n"
        "        \"reason\": \"%s (declared miss, gate-cure patrol)\",\n"
        "        \"patch-id\": \"%s\",\n"
        "    },\n" % (subject, date, sha, subject, pid)
        for sha, subject, pid in entries)
    text = text[:close] + "\n" + block + text[close + 1:]
    try:
        with open(guard_path, "w", encoding="utf-8") as fh:
            fh.write(text)
    except OSError:
        return ""
    entry = (
        "\n## %s — Kernel-gate red declared post-hoc (gate-cure)\n\n"
        "The gate-cure patrol found the loop-history guard red on %s.\n"
        "The commits were declared post-hoc (hash + patch-id) in the\n"
        "guard's KNOWN_EXEMPTIONS table and cured through the ceremony\n"
        "loop -- declared, not rewritten; the SMALL-matter policy is the\n"
        "2026-09-13 amendment (docs/design/autonomous-development-\n"
        "control.md). A ceremony refusal parks for the operator.\n"
        % (date, " ".join(shas)))
    try:
        with open(decisions_path, "a", encoding="utf-8") as fh:
            fh.write(entry)
    except OSError:
        return ""
    return "declared %s" % " ".join(sha for sha, _s, _p in entries)


def _drive_ceremony(kernel, objective, files):
    """The ceremony-drive seam: run scripts/ceremony-drive with a fresh
    /tmp store (PATROL_CEREMONY_BIN overrides, the rq-stub convention).
    Returns (rc, last output line)."""
    cmd = [os.environ.get(
               "PATROL_CEREMONY_BIN",
               os.path.join(kernel, "scripts", "ceremony-drive")),
           "--store=" + tempfile.mkdtemp(prefix="hngh-ceremony-"),
           objective] + list(files)
    try:
        r = subprocess.run(cmd, cwd=kernel, capture_output=True,
                           text=True, timeout=3600)
    except (subprocess.SubprocessError, OSError) as exc:
        return 1, str(exc)
    out = (r.stdout.strip().splitlines() or [""])[-1]
    return r.returncode, out


def cure_red_gate(kernel, shas, date):
    """Back off, consider, self-handle: declare the violating commits
    post-hoc, then drive the ceremony (commit + certificate-gated push).
    The ceremony's ten-principle verdict and verify-candidate (make
    test) stay the gate. Returns (ok, detail); a refusal parks."""
    if not shas:
        return False, "no violations parsed from a red gate"
    detail = append_exemptions(kernel, shas, date)
    if not detail:
        return False, "exemption append refused"
    rc, tail = _drive_ceremony(
        kernel,
        "declare kernel-gate violations post-hoc (gate-cure): "
        + " ".join(shas),
        [os.path.join(kernel, "tests", "scripts",
                      "test-loop-history-guard.py"),
         os.path.join(kernel, "docs", "project", "decisions.md")])
    if rc != 0:
        return False, "ceremony-drive rc=%d: %s" % (rc, tail)
    return True, "%s; ceremony committed and pushed (rc=0)" % detail


def check_gate_cure(ctx):
    """The red-gate cure (2026-09-13 SMALL-matter amendment): a
    machine-authored code-surface commit that the suite already
    validates is declared post-hoc through the ceremony loop, not
    parked. A refusal (LARGE surface, red suite, verdict refusal)
    files the alert and parks as before."""
    out = {"passes": [], "fails": []}
    rc, shas = guard_violations(ctx["kernel"])
    if rc is None:
        out["fails"].append(("kernel", "gate-stale",
                             "guard script missing or fault"))
        return out
    if rc == 0:
        out["passes"].append(("gate-cure", "gate green"))
        return out
    large = is_large_cure_violation(ctx["kernel"], shas)
    if large:
        out["fails"].append(("kernel", "gate-cure-refused",
                             "LARGE-surface pre-check: %s -- park for "
                             "the operator" % large))
        return out
    ok, detail = cure_red_gate(ctx["kernel"], shas, ctx["date"])
    if ok:
        out["passes"].append(("gate-cure", detail))
    else:
        out["fails"].append(("kernel", "gate-cure-refused", detail))
    return out


def check_feedback_backlog(ctx):
    """Dashboard feedback pipeline: unprocessed feedback/*.json backlog
    over the flood cap, or a missing processed/ dir (the dedupe sink
    feedback-ingest.py moves files into)."""
    out = {"passes": [], "fails": []}
    processed = os.path.join(ctx["feedback"], "processed")
    try:
        names = [n for n in os.listdir(ctx["feedback"])
                 if n.endswith(".json")]
    except OSError:
        out["passes"].append(("feedback-backlog",
                              "no feedback dir (no feedback yet)"))
        return out
    if not os.path.isdir(processed):
        out["fails"].append(("feedback/processed", "processed-missing",
                             "dedupe sink dir absent"))
    if len(names) > FEEDBACK_FLOOD:
        out["fails"].append(("feedback", "feedback-flood",
                             "%d unprocessed > %d"
                             % (len(names), FEEDBACK_FLOOD)))
    else:
        out["passes"].append(("feedback-backlog",
                              "backlog=%d cap=%d" % (len(names),
                                                     FEEDBACK_FLOOD)))
    return out


def check_manga_pipeline(ctx):
    """Manga pipeline: the newest draft json under docs/media/manga is
    the pipeline heartbeat -- stale beyond the window means the passes
    stopped; component prompts pending with no rendered panel.png in the
    same panel dir means a pass died mid-pipeline."""
    out = {"passes": [], "fails": []}
    drafts = []
    for dirpath, _dirs, files in os.walk(ctx["manga"]):
        for n in files:
            if "draft" in n and n.endswith(".json"):
                drafts.append(os.path.join(dirpath, n))
    if drafts:
        newest = max(os.path.getmtime(p) for p in drafts)
        age_h = (ctx["now"] - newest) / 3600.0
        if age_h > MANGA_STALE_HOURS:
            out["fails"].append(("manga", "manga-stale",
                                 "newest draft %.0fh old > %dh"
                                 % (age_h, MANGA_STALE_HOURS)))
        else:
            out["passes"].append(("manga-pipeline",
                                  "newest draft %.0fh old" % age_h))
    else:
        out["passes"].append(("manga-pipeline", "no drafts (nothing due)"))
    for dirpath, dirs, files in os.walk(ctx["manga"]):
        if "components" not in dirs:
            continue
        comps = os.path.join(dirpath, "components")
        prompts = [n for n in os.listdir(comps) if n.endswith(".json")]
        rendered = [n for n in files if n.endswith(".png")]
        if prompts and not rendered:
            out["fails"].append((os.path.relpath(dirpath, ctx["manga"]),
                                 "components-pending",
                                 "%d component prompt(s), 0 renders"
                                 % len(prompts)))
    return out


def check_email_sends(ctx):
    """Email side-channel: only the log bytes written since the LAST
    patrol run. A send failure in that window is a finding; historical
    failures are old news, not a recurring condition."""
    out = {"passes": [], "fails": []}
    tail = _email_tail(ctx)
    failed = [ln for ln in tail if "send failed rc=" in ln]
    ok = [ln for ln in tail if "send ok rc=0" in ln]
    if failed:
        out["fails"].append(("notify-email.log", "send-failed",
                             "%d failed send(s) since last patrol, last: %s"
                             % (len(failed), failed[-1][:120])))
    else:
        out["passes"].append(("email-sends",
                              "failed=%d ok=%d since last patrol"
                              % (len(failed), len(ok))))
    return out


def check_package_ghosts(ctx):
    """Packages registry: every in-use row's install-path must resolve
    on the host (the ghost-row rule, guard-enforced by
    test-hngh-packages.py -- patrolled here at runtime, because a row
    can rot between test runs)."""
    out = {"passes": [], "fails": []}
    try:
        with open(ctx["packages"], encoding="utf-8",
                  errors="replace") as fh:
            rows = [ln.rstrip("\n").split("\t") for ln in fh
                    if not ln.startswith("#")]
    except OSError:
        out["passes"].append(("package-ghosts", "no packages registry"))
        return out
    n = 0
    for f in rows:
        if len(f) < 8 or f[0] == "package" or f[7] != "in-use":
            continue
        if f[3].startswith("none-"):  # deliberately not installed
            continue
        target = f[3].split("(", 1)[0].strip()
        n += 1
        ok = (os.path.exists(target) if "/" in target
              else shutil.which(target) is not None)
        if not ok:
            out["fails"].append((f[0], "ghost-row",
                                 "in-use install-path does not resolve: %s"
                                 % f[3]))
    if not out["fails"]:
        out["passes"].append(("package-ghosts",
                              "%d in-use row(s) resolve" % n))
    return out


def check_service_children(ctx):
    """Services the automation manages: lib/comfyui.sh's contract is a
    TRANSIENT lifecycle (spawn -> use -> stop inside the run process,
    never a daemon) -- a managed child still alive at patrol time is a
    leak. Pattern = the last meaningful tokens of the row's
    start-command (--port 8188), so the check is registry-driven, not
    hardcoded."""
    out = {"passes": [], "fails": []}
    try:
        with open(ctx["services_tsv"], encoding="utf-8",
                  errors="replace") as fh:
            rows = [ln.rstrip("\n").split("\t") for ln in fh
                    if not ln.startswith("#")]
    except OSError:
        out["passes"].append(("service-children", "no services registry"))
        return out
    checked = 0
    for f in rows:
        if len(f) < 8 or f[0] == "service":
            continue
        svc, start, managed = f[0], f[4], f[6]
        if not managed.startswith("automation/") or not start:
            continue
        toks = start.replace("&&", " ").split()
        if not toks:
            continue
        # ponytail: last-two-token pgrep heuristic; a per-service pattern
        # column is the upgrade if a row ever needs more
        # a pattern may not begin with "-" (pgrep parses it as a flag)
        pattern = (" ".join([toks[-2].lstrip("-"), toks[-1]])
                   if toks[-1][:1].isdigit() else toks[-1].lstrip("-"))
        checked += 1
        try:
            r = subprocess.run(["pgrep", "-af", pattern],
                               capture_output=True, text=True, timeout=10)
        except (OSError, subprocess.SubprocessError) as exc:
            out["fails"].append((svc, "check-crash",
                                 "pgrep fault: %s" % exc.__class__.__name__))
            continue
        if r.returncode == 0:
            out["fails"].append((svc, "transient-left-running",
                                 "managed child alive outside a run: %s"
                                 % r.stdout.strip().splitlines()[0][:120]))
        else:
            out["passes"].append(("service-children:" + svc,
                                  "no transient child (pattern %r)"
                                  % pattern))
    if not out["fails"] and not out["passes"]:
        out["passes"].append(("service-children",
                              "no automation-managed rows"))
    return out


def check_disposition_followons(ctx):
    """Research dispositions: an `adopted` verdict is a promise -- the
    line must have a follow-on subject queued (a research-lines row or
    a research-subjects entry) or the finding dies in the ledger."""
    out = {"passes": [], "fails": []}
    try:
        with open(ctx["dispositions"], encoding="utf-8",
                  errors="replace") as fh:
            rows = [ln.rstrip("\n").split("\t") for ln in fh
                    if not ln.startswith("#")]
    except OSError:
        out["passes"].append(("disposition-followons",
                              "no dispositions tsv"))
        return out
    try:
        with open(ctx["research_lines"], encoding="utf-8",
                  errors="replace") as fh:
            line_ids = {ln.split("\t", 1)[0] for ln in fh
                        if ln.strip() and not ln.startswith("#")}
    except OSError:
        line_ids = set()
    try:
        subjects = open(ctx["subjects"], encoding="utf-8",
                        errors="replace").read().lower()
    except OSError:
        subjects = ""
    adopted = 0
    for f in rows:
        if len(f) < 2 or f[1] != "adopted":
            continue
        lid = f[0]
        adopted += 1
        if lid in line_ids or lid.replace("-", " ") in subjects:
            continue
        out["fails"].append((lid, "adopted-no-followon",
                             "adopted but no research-lines row or "
                             "queued subject carries it"))
    if not out["fails"]:
        out["passes"].append(("disposition-followons",
                              "%d adopted row(s) have follow-ons"
                              % adopted))
    return out


CRITICAL_TIMERS = ("hngh-automation.timer", "hngh-cadence-1m.timer",
                   "hngh-cadence-5m.timer", "hngh-overnight.timer")


def check_systemd_units(ctx):
    """Machine eyes on its own infrastructure: every critical hngh
    timer unit must be enabled AND active in the user manager. The
    2026-09-13 CachyOS update silently disabled the whole set and
    nothing self-detected it -- this patrol closes that gap. Tests stub
    systemctl via PATROL_SYSTEMCTL."""
    out = {"passes": [], "fails": []}
    ctl = os.environ.get("PATROL_SYSTEMCTL", "systemctl")
    for unit in CRITICAL_TIMERS:
        try:
            en = subprocess.run([ctl, "--user", "is-enabled", unit],
                                capture_output=True, text=True, timeout=15)
            ac = subprocess.run([ctl, "--user", "is-active", unit],
                                capture_output=True, text=True, timeout=15)
        except (OSError, subprocess.SubprocessError) as exc:
            out["fails"].append((unit, "check-crash",
                                 "systemctl unreadable: %s" % exc.__class__.__name__))
            continue
        en_s = (en.stdout.strip() or en.stderr.strip() or "rc=%d" % en.returncode)
        ac_s = (ac.stdout.strip() or ac.stderr.strip() or "rc=%d" % ac.returncode)
        if en.returncode != 0 or ac.returncode != 0:
            out["fails"].append((unit, "timer-dead",
                                 "enabled=%s active=%s" % (en_s, ac_s)))
        else:
            out["passes"].append(("systemd-units:" + unit,
                                  "enabled=%s active=%s" % (en_s, ac_s)))
    return out


JOURNAL_ACTIONS = ("transient", "restart-unit", "propose", "alert")


def load_journal_sigs(path, out):
    """journal-patrol.tsv -> [(id, kind, compiled, action, guard)]. The
    action column IS the corrective allowlist: a row with an action
    outside JOURNAL_ACTIONS, or an uncompilable regex, is a config-bug
    FAIL -- the table refuses anything it cannot vouch for, it never
    silently skips."""
    sigs = []
    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            rows = [ln.rstrip("\n").split("\t") for ln in fh
                    if ln.strip() and not ln.startswith("#")]
    except OSError:
        out["passes"].append(("journal-error:no-signature-table",
                              "no %s -- dormant channel" % path))
        return sigs
    for f in rows:
        if len(f) < 4 or f[0] == "id":
            continue
        f = f + [""] * (5 - len(f))  # guard column optional
        if f[3] not in JOURNAL_ACTIONS:
            out["fails"].append((f[0], "config-bug",
                                 "action %r outside the allowlist" % f[3]))
            continue
        try:
            rx = re.compile(f[2])
        except re.error as exc:
            out["fails"].append((f[0], "config-bug",
                                 "uncompilable regex: %s" % exc))
            continue
        sigs.append((f[0], f[1], rx, f[3], f[4]))
    return sigs


def journal_lines(ctx, out):
    """[(message, priority, epoch)] warning-and-worse from both
    journals (user + kernel), since the epoch watermark. Cold start
    baselines at now: boot history is old news, not a finding. The
    watermark advances only when BOTH streams read clean -- a failed
    stream keeps the old window, and the guarded actions make the one
    repeated window safe. Tests stub the binary via PATROL_JOURNALCTL."""
    ctl = os.environ.get("PATROL_JOURNALCTL", "journalctl")
    try:
        since = int(open(ctx["journal_state"],
                         encoding="utf-8").read().strip())
    except (OSError, ValueError):
        since = int(ctx["now"])
    lines, ok = [], True
    for flags in (["--user"], ["-k"]):
        try:
            r = subprocess.run(
                [ctl, *flags, "-b", "-p", "warning",
                 "--since=@%d" % since, "--output=json", "--no-pager"],
                capture_output=True, text=True, timeout=90)
        except (OSError, subprocess.SubprocessError) as exc:
            out["fails"].append(("journalctl-" + flags[-1].strip("-"),
                                 "check-crash",
                                 "journalctl fault: %s"
                                 % exc.__class__.__name__))
            ok = False
            continue
        if r.returncode != 0:
            detail = "rc=%d" % r.returncode
            if r.stderr.strip():
                detail += " " + r.stderr.strip().splitlines()[-1][:120]
            out["fails"].append(("journalctl-" + flags[-1].strip("-"),
                                 "journal-unreadable", detail))
            ok = False
            continue
        for ln in r.stdout.splitlines():
            try:
                j = json.loads(ln)
                lines.append((str(j.get("MESSAGE", "")),
                              int(j.get("PRIORITY", 6)),
                              int(j.get("__REALTIME_TIMESTAMP", 0)) // 1000000))
            except (ValueError, TypeError):
                pass  # unparseable line: fail open, keep walking
    if ok:
        try:
            with open(ctx["journal_state"], "w", encoding="utf-8") as fh:
                fh.write(str(int(ctx["now"])))
        except OSError:
            pass  # lost mark = next run re-baselines, never a crash
    return lines


def journal_guard(guard):
    """Guard column -> params: alert>=N (transient threshold, default
    10), max=N (restart-unit daily cap, default 2), units=a,b (restart
    allowlist, default empty = nobody is restartable), unit=NAME (pin
    the restarted unit when the regex captures a DBus name, not the
    systemd unit -- the pinned name is the operator-verified command),
    cmd=... (propose recommendation, never executed)."""
    g = {"threshold": 10, "max": 2, "units": set(), "unit": "", "cmd": ""}
    for tok in (guard or "").split():
        k, _, v = tok.partition("=")
        if k == "units":
            g["units"] = {u for u in v.split(",") if u}
        elif k == "unit":
            g["unit"] = v
        elif k in ("max", "alert") and v.lstrip(">=").isdigit():
            g["threshold" if k == "alert" else "max"] = int(v.lstrip(">="))
    if "cmd=" in (guard or ""):
        g["cmd"] = guard.split("cmd=", 1)[1].strip()
    return g


def journal_counts_load(path, day):
    """journal-patrol-counts.tsv -> {(sig, unit): n} for the UTC day.
    One line per applied restart: the restart-loop guard's memory."""
    try:
        text = open(path, encoding="utf-8").read()
    except OSError:
        return {}
    cur = {}
    for ln in text.splitlines():
        f = ln.split("\t")
        if len(f) == 4 and f[2] == day:
            try:
                cur[(f[0], f[1])] = int(f[3])
            except ValueError:
                pass
    return cur


def journal_counts_save(path, counts, day):
    try:
        with open(path, "w", encoding="utf-8") as fh:
            for (sig, unit), n in sorted(counts.items()):
                fh.write("%s\t%s\t%s\t%d\n" % (sig, unit, day, n))
    except OSError:
        pass  # lost counts = cap resets; restart-unit stays capped per run


def check_journal_errors(ctx):
    """The journal rounds: warning-and-worse journal lines since the
    last run matched against config/journal-patrol.tsv, first match
    wins. The action column IS the corrective allowlist -- nothing
    outside it acts. A line matching NO signature stays silent at
    warning level, but an err-or-worse line that nothing claims is an
    unknown-journal-error FAIL: unknown errors are never silenced, the
    repeated pair auto-queues research (house convention)."""
    out = {"passes": [], "fails": []}
    sigs = load_journal_sigs(ctx["journal_sigs"], out)
    hits, unknown = {}, []
    for msg, pri, _ts in journal_lines(ctx, out):
        for sig, _kind, rx, action, guard in sigs:
            m = rx.search(msg)
            if m:
                hits.setdefault((sig, action, guard), []).append((m, msg))
                break
        else:
            if pri <= 3:
                unknown.append(msg)
    for (sig, action, guard), ms in hits.items():
        g = journal_guard(guard)
        latest = ms[-1][1][:110]
        if action == "transient":
            if len(ms) >= g["threshold"]:
                out["fails"].append((sig, "transient-escalation",
                                     "%d hits >= alert>=%d; latest: %s"
                                     % (len(ms), g["threshold"], latest)))
            else:
                out["passes"].append(("journal-error:" + sig,
                                      "%d hit(s) counted (alert>=%d), quiet: %s"
                                      % (len(ms), g["threshold"], latest)))
        elif action == "restart-unit":
            unit = (g["unit"] or ms[-1][0].group(1)
                    or "(no unit captured)")
            if not g["unit"] and unit not in g["units"]:
                out["fails"].append((sig, "unit-not-practiced",
                                     "%s failed; not in the restart allowlist, "
                                     "no auto-action: %s" % (unit, latest)))
                continue
            done = journal_counts_load(ctx["journal_counts"], ctx["date"])
            n = done.get((sig, unit), 0)
            if n >= g["max"]:
                out["fails"].append((sig, "restart-guard",
                                     "%s at the daily cap (%d/%d); human eyes"
                                     % (unit, n, g["max"])))
                continue
            ctl = os.environ.get("PATROL_SYSTEMCTL", "systemctl")
            try:
                r = subprocess.run([ctl, "--user", "restart", unit],
                                   capture_output=True, text=True, timeout=30)
            except (OSError, subprocess.SubprocessError) as exc:
                out["fails"].append((sig, "restart-failed",
                                     "systemctl fault on %s: %s"
                                     % (unit, exc.__class__.__name__)))
                continue
            if r.returncode != 0:
                err = (r.stderr.strip().splitlines() or [""])[-1][:100]
                out["fails"].append((sig, "restart-failed",
                                     "systemctl --user restart %s rc=%d %s"
                                     % (unit, r.returncode, err)))
                continue
            done[(sig, unit)] = n + 1
            journal_counts_save(ctx["journal_counts"], done, ctx["date"])
            out["passes"].append(("journal-error:" + sig,
                                  "%s -> restart-unit applied: systemctl "
                                  "--user restart %s (today %d/%d)"
                                  % (sig, unit, n + 1, g["max"])))
        elif action == "propose":
            out["fails"].append((sig, "propose",
                                 "%d hit(s); NOT auto-applied (live-session "
                                 "fix, operator eyes): %s -- latest: %s"
                                 % (len(ms), g["cmd"], latest)))
        else:  # alert: evidence only, no side effect
            out["fails"].append((sig, "alert",
                                 "%d hit(s), no auto-action; latest: %s"
                                 % (len(ms), latest)))
    if unknown:
        out["fails"].append(("unknown-journal-error", "unclaimed-err",
                             "%d err+ line(s) no signature claims; latest: %s"
                             % (len(unknown), unknown[-1][:100])))
    return out


def check_pending_checks(ctx):
    """Correction convergence fold (2026-09-15): each pending named check
    from state/pending-checks.tsv surfaces once as check-pending:<id>
    until promoted (the row is removed); rows older than 7 days escalate
    as check-pending-stale:<id>."""
    out = {"passes": [], "fails": []}
    import importlib.util as _ilu
    _spec = _ilu.spec_from_file_location(
        "correction_linkage",
        os.path.join(HERE, os.pardir, "lib", "correction-linkage.py"))
    correction_linkage = _ilu.module_from_spec(_spec)
    _spec.loader.exec_module(correction_linkage)
    rows = correction_linkage.load_pending(ctx["pending_checks"])
    if not rows:
        out["passes"].append(("pending-checks",
                              "no pending checks (nothing converged)"))
        return out
    stale_s = correction_linkage.STALE_DAYS * 86400
    stale = pending = 0
    for r in rows:
        if r["status"] != "pending":
            continue
        pending += 1
        try:
            created = time.mktime(time.strptime(
                r["created"], "%Y-%m-%dT%H:%M:%SZ")) - time.timezone
        except ValueError:
            created = 0
        if ctx["now"] - created > stale_s:
            stale += 1
            out["fails"].append(
                (r["id"], "check-pending-stale",
                 "%s (%s) pending since %s: %s (promote into "
                 "config/patrol-routes.tsv or park it)"
                 % (r["check"], r["id"], r["created"],
                    r["condition"][:80])))
        else:
            out["fails"].append(
                (r["id"], "check-pending",
                 "%s awaiting promotion (tier %s): %s"
                 % (r["check"], r["tier"], r["condition"][:80])))
    out["passes"].append(("pending-checks",
                          "pending=%d stale=%d" % (pending, stale)))
    return out


def _roadmap_movements(ctx):
    """[(epoch, subject, path)] of recent movement evidence for the
    roadmap/records fold. Documented heuristic (2026-09-15): movement
    is any commit in the last ROADMAP_HISTORY_DAYS whose changed path
    is docs/project/roadmap.md OR a docs/records/ file whose name or
    the commit subject mentions 'stage<N>'. A `git log --format=%ct
    -1 -L` per row was considered and rejected as fragile (row text
    shifts across merges); path-level movement is honest enough to
    catch "this stage's surface moved". Overridable by
    PATROL_ROADMAP_GIT_LOG (a fixture file of '<epoch>\\t<subject>\\t
    <path>' lines) so the check stays hermetic under test."""
    since = ctx["now"] - ROADMAP_HISTORY_DAYS * 86400
    fixture = os.environ.get("PATROL_ROADMAP_GIT_LOG")
    rows = []
    if fixture:
        try:
            with open(fixture, encoding="utf-8", errors="replace") as fh:
                for ln in fh:
                    f = ln.rstrip("\n").split("\t")
                    if len(f) == 3:
                        rows.append((int(f[0]), f[1], f[2]))
        except (OSError, ValueError):
            pass
        return rows
    try:
        r = subprocess.run(
            ["git", "-C", ctx["kernel"], "log",
             "--since=@%d" % int(since), "--name-only", "--pretty="
             "format:%ct%x09%s"],
            capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError):
        return []
    subject, ts = "", None
    for ln in r.stdout.splitlines():
        if "\t" in ln and ln.split("\t")[0].isdigit():
            head = ln.split("\t")
            ts, subject = int(head[0]), head[1]
            continue
        if not ln.strip() or ts is None:
            continue
        rows.append((ts, subject, ln.strip()))
    return rows


STAGE_ROW_RE = re.compile(
    r"^\|\s*\*\*(\d+)\s*[^*]*?[—-]\s*([^*]+)\*\*.*\*\*(green|landing|done)\*\*",
    re.IGNORECASE)


def check_roadmap_stale(ctx):
    """Roadmap rot fold (2026-09-15, adversarial pass): stages 2/3 sat
    'landing' ~3 weeks with unchanged frontier text while the roadmap
    claims 'a stage is done when its exit criteria hold'. For each
    'landing' stage row, movement = a commit in the last
    ROADMAP_HISTORY_DAYS touching docs/project/roadmap.md or a
    docs/records/ file whose name/subject mentions 'stage<N>' (exact
    heuristic in _roadmap_movements). No movement within
    ROADMAP_STALE_DAYS -> fail identity stage:stage<N>-stale (the
    report-queue identity dedups repeats). Missing roadmap fails soft:
    a dormant surface is quiet, never a crash."""
    out = {"passes": [], "fails": []}
    path = os.path.join(ctx["kernel"], "docs", "project", "roadmap.md")
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        out["passes"].append(("roadmap-stale", "no roadmap (dormant)"))
        return out
    landing = []
    for ln in text.splitlines():
        m = STAGE_ROW_RE.match(ln)
        if m and m.group(3).lower() == "landing":
            landing.append((m.group(1), m.group(2)))
    if not landing:
        out["passes"].append(("roadmap-stale", "no landing stages"))
        return out
    movements = [mv for mv in _roadmap_movements(ctx)
                 if mv[0] >= ctx["now"] - ROADMAP_HISTORY_DAYS * 86400]
    stale_s = ROADMAP_STALE_DAYS * 86400
    for n, name in landing:
        stage_tok = "stage%s" % n
        alt_tok = "stage-%s" % n
        # stage-name tokens: distinctive words of the stage title, so a
        # record like governed-fleet.md counts as stage-3 movement even
        # when it never says "stage3"
        name_toks = [w.lower() for w in re.findall(r"[A-Za-z]{4,}", name)]
        # a commit moves ONE stage only when its subject/path names that
        # stage (stage2/stage-2 or a distinctive stage-title word,
        # normalized so "stage 2 polish" matches "stage2"); a bare
        # roadmap.md touch is not evidence for every landing stage
        toks = tuple(re.sub(r"[^a-z0-9]", "", t)
                     for t in (stage_tok, alt_tok) + tuple(name_toks))
        recent = [mv for mv in movements
                  if any(tok in re.sub(r"[^a-z0-9]", "",
                                       (mv[2] + " " + mv[1]).lower())
                         for tok in toks)]
        if not recent:
            out["fails"].append(
                (stage_tok, "%s-stale" % stage_tok,
                 "stage %s landing with no roadmap/records movement "
                 "in %dd" % (n, ROADMAP_HISTORY_DAYS)))
            continue
        age_d = (ctx["now"] - max(mv[0] for mv in recent)) / 86400.0
        if age_d >= ROADMAP_STALE_DAYS:
            out["fails"].append(
                (stage_tok, "%s-stale" % stage_tok,
                 "stage %s landing, newest movement %.1fd old (>= %dd)"
                 % (n, age_d, ROADMAP_STALE_DAYS)))
        else:
            out["passes"].append(
                (stage_tok, "moved %.1fd ago (%s)"
                 % (age_d, max(recent, key=lambda mv: mv[0])[1][:60])))
    return out


NEXT_RE = re.compile(r"^- \*\*([A-Za-z0-9._-]+)\*\*\s*[—-]")


def check_rotation_due(ctx):
    """Queue rotation fold (2026-09-15, adversarial pass): items marked
    unblocked ('## Next' in docs/project/queue.md, `- **<id>** - <why>`
    shape) never rotate -- nothing machine-checks rotation readiness.
    First-seen per Next item is tracked in state/rotation-watch.tsv
    (TSV: item\\tfirst-seen ISO Z; the beat-blockers.tsv flat-row
    convention, created on demand). The Next item held >=
    ROTATION_DUE_DAYS -> fail identity queue:rotation-due with the id
    and age; a changed Next item replaces the watch row (reset)."""
    out = {"passes": [], "fails": []}
    path = os.path.join(ctx["kernel"], "docs", "project", "queue.md")
    try:
        text = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        out["passes"].append(("rotation-due", "no queue (dormant)"))
        return out
    nxt = None
    in_next = False
    for ln in text.splitlines():
        if ln.startswith("## "):
            in_next = ln.strip() == "## Next"
            continue
        if in_next:
            m = NEXT_RE.match(ln.strip())
            if m:
                nxt = m.group(1)
    if not nxt:
        out["passes"].append(("rotation-due", "no Next item named"))
        return out
    watch = ctx["rotation_watch"]
    rows = {}
    try:
        with open(watch, encoding="utf-8", errors="replace") as fh:
            for ln in fh:
                f = ln.rstrip("\n").split("\t")
                if len(f) == 2:
                    rows[f[0]] = f[1]
    except OSError:
        pass
    if nxt not in rows:
        rows = {nxt: time.strftime(
            "%Y-%m-%dT%H:%M:%SZ", time.gmtime(ctx["now"]))}
        try:
            os.makedirs(os.path.dirname(watch), exist_ok=True)
            with open(watch, "w", encoding="utf-8") as fh:
                for k in sorted(rows):
                    fh.write("%s\t%s\n" % (k, rows[k]))
        except OSError:
            pass  # lost watch = next run re-baselines, never a crash
        out["passes"].append((nxt, "watch row created (reset)"))
        return out
    first = ts_epoch(rows[nxt])
    if first is None:
        # unparseable first-seen: re-baseline, fail soft
        rows.pop(nxt)
        out["passes"].append((nxt, "watch row unparseable, re-baselined"))
        return out
    age_d = (ctx["now"] - first) / 86400.0
    if age_d >= ROTATION_DUE_DAYS:
        out["fails"].append(
            (nxt, "rotation-due",
             "%s named Next for %.1fd (>= %dd): rotate it or re-rank it"
             % (nxt, age_d, ROTATION_DUE_DAYS)))
    else:
        out["passes"].append(
            (nxt, "Next %.1fd old (< %dd)" % (age_d, ROTATION_DUE_DAYS)))
    return out


CHECKS = {
    "feed-freshness": check_feed_freshness,
    "blocker-escalations": check_blocker_escalations,
    "handoff-deaths": check_handoff_deaths,
    "stall-crumbs": check_stall_crumbs,
    "gate-crumbs": check_gate_crumbs,
    "paper-edition": check_paper_edition,
    "service-health": check_service_health,
    "disk-usage": check_disk_usage,
    "research-stall": check_research_stall,
    "research-ledger": check_research_ledger,
    "session-budget": check_session_budget,
    "loop-history-guard": check_loop_history_guard,
    "gate-cure": check_gate_cure,
    "feedback-backlog": check_feedback_backlog,
    "manga-pipeline": check_manga_pipeline,
    "email-sends": check_email_sends,
    "package-ghosts": check_package_ghosts,
    "service-children": check_service_children,
    "disposition-followons": check_disposition_followons,
    "systemd-units": check_systemd_units,
    "github-ci-latest": check_github_ci,
    "journal-errors": check_journal_errors,
    "pending-checks": check_pending_checks,
    "roadmap-stale": check_roadmap_stale,
    "rotation-due": check_rotation_due,
}


def load_routes(path):
    """patrol-routes.tsv rows -> [{id, surface, check, tier, finding}]"""
    routes = []
    with open(path, encoding="utf-8", errors="replace") as fh:
        for ln in fh:
            if ln.startswith("#") or ln.startswith("patrol-id"):
                continue
            f = ln.rstrip("\n").split("\t")
            if len(f) >= 5 and f[0] and f[2]:
                routes.append({"id": f[0], "surface": f[1], "check": f[2],
                               "tier": f[3], "finding": f[4]})
    return routes


GATE_LABELS = {"automation-gate": "hngh-automation"}


def build_ctx(args, now_s):
    root = os.path.abspath(args.repo)
    kernel = os.path.abspath(args.kernel)
    date = time.strftime("%Y-%m-%d", time.gmtime(now_s))
    params = os.environ.get(
        "PATROL_PARAMS", os.path.join(root, "cadence-params.tsv"))
    return {
        "root": root,
        "kernel": kernel,
        "now": now_s,
        "now_struct": time.gmtime(now_s),
        "date": date,
        "state": os.environ.get("PATROL_STATE_FILE",
                                os.path.join(root, "STATE.md")),
        "handoffs": os.environ.get(
            "PATROL_HANDOFFS", os.path.join(root, "agent-handoffs.md")),
        "blockers": os.environ.get(
            "PATROL_BLOCKERS",
            os.path.join(root, "state", "beat-blockers.tsv")),
        "pending_checks": os.environ.get(
            "PATROL_PENDING_CHECKS",
            os.path.join(root, "state", "pending-checks.tsv")),
        "params": params,
        "research_lines": os.environ.get(
            "PATROL_RESEARCH_LINES", os.path.join(root, "research-lines.tsv")),
        "budget_log": os.environ.get(
            "PATROL_BUDGET_LOG", os.path.join(root, "logs", "budget.md")),
        "services_tsv": os.environ.get(
            "PATROL_SERVICES_TSV",
            os.path.join(root, "config", "hngh-services.tsv")),
        "subjects": os.environ.get(
            "PATROL_SUBJECTS", os.path.join(root, "research-subjects.txt")),
        "digest_dir": os.environ.get(
            "PATROL_DIGEST_DIR", os.path.join(
                os.environ.get("HNGH_HOME_DIR")
                or os.path.join(os.path.expanduser("~"), ".hngh"),
                "archive", "digest")),
        "feedback": os.environ.get(
            "PATROL_FEEDBACK",
            os.path.join(root, "dashboard", "feedback")),
        "packages": os.environ.get(
            "PATROL_PACKAGES",
            os.path.join(root, "config", "hngh-packages.tsv")),
        "email_log": os.environ.get(
            "PATROL_EMAIL_LOG",
            os.path.join(root, "logs", "notify-email.log")),
        "manga": os.environ.get(
            "PATROL_MANGA",
            _manga_dir(root)),
        "dispositions": os.environ.get(
            "PATROL_DISPOSITIONS",
            os.path.join(root, "research-dispositions.tsv")),
        "journal_sigs": os.environ.get(
            "PATROL_JOURNAL_SIGS",
            os.path.join(root, "config", "journal-patrol.tsv")),
        "journal_state": os.environ.get(
            "PATROL_JOURNAL_STATE",
            os.path.join(root, "logs", "journal-patrol.watermark")),
        "journal_counts": os.environ.get(
            "PATROL_JOURNAL_COUNTS",
            os.path.join(root, "logs", "journal-patrol-counts.tsv")),
        "rotation_watch": os.environ.get(
            "PATROL_ROTATION_WATCH",
            os.path.join(root, "state", "rotation-watch.tsv")),
    }


def read_runs(digest_dir, date, now_s):
    """Existing patrol findings sections, oldest first: [(fails)] where
    fails are (patrol, cause). Reads yesterday's + today's file -- the
    findings doc is the only patrol state there is."""
    out = []
    day = time.strptime(date, "%Y-%m-%d")
    import datetime  # local import: only needed for the day arithmetic
    yday = datetime.date(day.tm_year, day.tm_mon, day.tm_mday)
    yday -= datetime.timedelta(days=1)
    for fname in ("%s.md" % yday.isoformat(), "%s.md" % date):
        path = os.path.join(digest_dir, "PATROL-" + fname)
        try:
            text = open(path, encoding="utf-8", errors="replace").read()
        except OSError:
            continue
        cur = []
        for ln in text.splitlines():
            if ln.startswith("## ") and ln.endswith(" run"):
                if cur:
                    out.append(cur)
                cur = []
                continue
            m = re.match(r"- FAIL ([\w-]+)/[^:]+: ([\w-]+)", ln)
            if m:
                cur.append((m.group(1), m.group(2)))
        if cur:
            out.append(cur)
    return out


def findings_md(now_s, date, results, quip_line):
    """One run section, publication-review two-pass format. Every detail
    line is scrubbed at the writer (digest writer census 2026-09-16):
    FAIL details are journal/log-derived free text, and this doc feeds
    read_runs (repeat detection) AND the morning rounds -- but it is
    never an operator-visible surface, so the guard here is the
    fail-details-in-two-places defense, the visible guard is
    morning_report's."""
    ts = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now_s))
    out = ["## %s run" % ts, ""]
    if quip_line:
        out.append("_%s_" % quip_line)
        out.append("")
    out += ["### Supportive pass", ""]
    for r in results:
        for name, detail in r["passes"]:
            out.append("- [ok] %s -- %s" % (name, detail))
    out += ["", "### Adversarial pass", ""]
    for r in results:
        for artifact, cause, detail in r["fails"]:
            out.append("- FAIL %s/%s: %s -- %s"
                       % (r["id"], artifact, cause, scrub_paths(detail)))
        if not r["fails"]:
            out.append("- ok %s -- no red findings" % r["id"])
    # the rounds: each FAIL mapped to the surface it touches and the
    # artifact to look at -- the operator's morning checklist (the
    # night-watch precedent, mechanized)
    rounds = [(r, f) for r in results for f in r["fails"]]
    if rounds:
        out += ["", "### The rounds", ""]
        for r, (artifact, cause, detail) in rounds:
            out.append("- ROUNDS %s -> surface: %s; artifact: %s "
                       "(%s)" % (r["id"], r["surface"], artifact, cause))
    return "\n".join(out) + "\n"


def queue_repeat_subjects(ctx, prev_fails, cur_fails):
    """A patrol+cause on two consecutive runs auto-queues a
    research-subjects entry (house convention): the patrol found the
    pattern, the research beat crystallizes the lesson. Returns rids."""
    queued = []
    prev = set(prev_fails) if prev_fails else set()
    repeats = prev & set(cur_fails)
    if not repeats:
        return queued
    rid_day = time.strftime("%Y%m%d", time.gmtime(ctx["now"]))
    try:
        seen = set(open(ctx["subjects"], encoding="utf-8",
                        errors="replace").read().splitlines())
    except OSError:
        seen = set()
    for patrol, cause in sorted(repeats):
        rid = "patrol-%s-%s-%s" % (rid_day, patrol, cause)
        q = ("patrol: surface %s filed %s on two consecutive runs -- "
             "why does it keep failing and which guardrail closes it?"
             % (patrol, cause))[:240]
        line = "%s\t%s" % (rid, q)
        if line in seen:
            continue
        try:
            with open(ctx["subjects"], "a", encoding="utf-8") as fh:
                fh.write(line + "\n")
            queued.append(rid)
        except OSError:
            pass
    return queued


def report_alert(text, identity, evidence=None):
    """report-queue alert; best-effort (a lost queue write is a stderr
    line, never a crash). EVIDENCE: a token derived from the current
    failing state (e.g. the failing detail line). With evidence, the
    dedup only re-fires when the CONDITION recurred (new failing log
    line / new count); an unchanged stale condition is suppressed."""
    bin_path = os.environ.get(
        "REPORT_QUEUE_BIN", os.path.join(REPO, "scripts", "report-queue"))
    env = dict(os.environ,
               HNGH_REPORT_ROOT=os.environ.get("PATROL_REPORT_ROOT", REPO))
    try:
        argv = [bin_path, "--add", "alert", text,
                "--identity", identity, "--window", "86400"]
        if evidence:
            argv += ["--evidence", evidence]
        r = subprocess.run(argv,
                           stdout=subprocess.DEVNULL,
                           stderr=subprocess.DEVNULL, env=env, timeout=30)
        return r.returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def run(tier=None, patrol_id=None, now_s=None):
    """Walk the routes -> (results, exit_code). Prints the PASS/FAIL
    machine contract, files alerts, writes findings, queues repeats."""
    if now_s is None:
        now_s = float(os.environ.get("PATROL_NOW_EPOCH", time.time()))
    date = time.strftime("%Y-%m-%d", time.gmtime(now_s))
    args = argparse.Namespace(
        repo=os.environ.get("PATROL_ROOT", ROOT),
        kernel=os.environ.get("PATROL_KERNEL", REPO), date=date)
    ctx = build_ctx(args, now_s)
    routes_path = os.environ.get(
        "PATROL_ROUTES",
        os.path.join(ctx["root"], "config", "patrol-routes.tsv"))
    routes = load_routes(routes_path)
    if patrol_id is not None:
        sel = [r for r in routes if r["id"] == patrol_id]
        if not sel:
            print("patrol: unknown patrol id '%s'" % patrol_id, file=sys.stderr)
            return [], 2
    elif tier:
        sel = [r for r in routes if r["tier"] == tier]
    else:
        sel = routes
    results = []
    for r in sel:
        c = dict(ctx)
        if r["check"] == "gate-crumbs":
            c["gate_label"] = GATE_LABELS.get(r["surface"], r["surface"])
        fn = CHECKS.get(r["check"])
        res = {"id": r["id"], "surface": r["surface"],
               "passes": [], "fails": []}
        try:
            if fn is None:
                res["fails"].append(
                    (r["surface"], "unknown-check", "no CHECKS entry"))
            else:
                res.update(fn(c))
        except Exception as exc:  # noqa: BLE001 -- fail open, keep walking
            res["passes"] = res.get("passes", [])
            res["fails"] = [(r["surface"], "check-crash", repr(exc))]
        results.append(res)
    return results, 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--patrol", metavar="ID")
    ap.add_argument("--tier", choices=["30m", "day"])
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--morning", action="store_true",
                    help="emit the morning rounds digest section")
    ap.add_argument("--repo", default=os.environ.get("PATROL_ROOT", ROOT))
    ap.add_argument("--kernel", default=os.environ.get("PATROL_KERNEL", REPO))
    args = ap.parse_args(argv)
    now_s = float(os.environ.get("PATROL_NOW_EPOCH", time.time()))
    if args.morning:
        return morning_report(now_s)
    results, rc = run(tier=args.tier, patrol_id=args.patrol, now_s=now_s)
    if rc:
        return rc
    fails = [(r["id"], f) for r in results for f in r["fails"]]
    for r in results:
        for name, detail in r["passes"]:
            print("PASS %s/%s %s" % (r["id"], name, detail))
        for artifact, cause, detail in r["fails"]:
            print("FAIL %s/%s %s %s" % (r["id"], artifact, cause, detail))
    # findings doc: one section per run; the previous section is the
    # repeat-detection memory
    date = time.strftime("%Y-%m-%d", time.gmtime(now_s))
    ctx = build_ctx(args, now_s)
    digest_dir = ctx["digest_dir"]
    os.makedirs(digest_dir, exist_ok=True)
    prev_runs = read_runs(digest_dir, date, now_s)
    cur = [(" ".join([pid, f[1]]).strip(), f[0], f[2]) for pid, f in fails]
    quip_line = ""
    try:
        sys.path.insert(0, os.path.join(ctx["root"], "lib"))
        import quips
        quip_line = quips.quip("patrol", date,
                               surfaces=len(results),
                               passes=sum(len(r["passes"]) for r in results),
                               fails=len(fails)) or ""
    except Exception:  # noqa: BLE001 -- no quip, never a crash
        quip_line = ""
    path = os.path.join(digest_dir, "PATROL-%s.md" % date)
    section = findings_md(now_s, date, results, quip_line)
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(section)
    if fails:
        for pid, (artifact, cause, detail) in fails:
            report_alert("patrol %s: %s on %s -- %s"
                         % (pid, cause, artifact, detail),
                         "patrol:" + pid, evidence=detail)
        queued = queue_repeat_subjects(
            ctx, prev_runs[-1] if prev_runs else [],
            [(pid, cause) for pid, (a, cause, d) in fails])
        for rid in queued:
            print("QUEUED research-subject %s" % rid)
    return 0


def morning_report(now_s):
    """--morning: summarize today's findings doc into the daily digest
    as an append-only `## The rounds` section (PASS/FAIL counts, causes,
    the top-3 items for operator attention). Runs the walk first when
    nothing has patrolled today."""
    args = argparse.Namespace(
        repo=os.environ.get("PATROL_ROOT", ROOT),
        kernel=os.environ.get("PATROL_KERNEL", REPO),
        date=time.strftime("%Y-%m-%d", time.gmtime(now_s)))
    ctx = build_ctx(args, now_s)
    findings = os.path.join(ctx["digest_dir"],
                            "PATROL-%s.md" % ctx["date"])
    if not os.path.exists(findings):
        main(["--all"])
    passes = fails = 0
    fail_rows = []
    try:
        for ln in open(findings, encoding="utf-8", errors="replace"):
            if ln.startswith("- [ok] "):
                passes += 1
            elif ln.startswith("- FAIL "):
                fails += 1
                m = re.match(r"- FAIL ([\w-]+)/([^:]+): ([\w-]+) -- (.*)",
                             ln.rstrip("\n"))
                if m:
                    fail_rows.append(m.groups())
    except OSError:
        pass
    causes = {}
    for _pid, _art, cause, _d in fail_rows:
        causes[cause] = causes.get(cause, 0) + 1
    out = ["## The rounds",
           "",
           "PASS %d, FAIL %d (%s)"
           % (passes, fails,
              ", ".join("%s x%d" % (c, n)
                        for c, n in sorted(causes.items(),
                                           key=lambda kv: -kv[1]))
              or "no causes"),
           ""]
    surface_of = {r["id"]: r["surface"]
                  for r in load_routes(os.environ.get(
                      "PATROL_ROUTES", os.path.join(
                          ctx["root"], "config", "patrol-routes.tsv")))}
    seen = set()
    top = []
    for pid, art, cause, detail in fail_rows:
        if pid in seen:
            continue
        seen.add(pid)
        top.append("%d. %s (%s): %s on %s -- %s"
                   % (len(top) + 1, pid, surface_of.get(pid, "?"),
                      cause, art, scrub_paths(detail)))
        if len(top) == 3:
            break
    if top:
        out += ["Top items for operator attention:"] + top
    else:
        out.append("All quiet -- nothing needs the operator this morning.")
    section = "\n".join(out) + "\n"
    os.makedirs(ctx["digest_dir"], exist_ok=True)
    with open(os.path.join(ctx["digest_dir"], "%s.md" % ctx["date"]),
              "a", encoding="utf-8") as fh:
        fh.write(section)
    print(section, end="")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except SystemExit:
        raise
    except Exception as exc:  # noqa: BLE001 -- fail-first on the patrol
        # itself: a runner crash files one alert and exits 0 (a crumb,
        # never tick damage)
        print("patrol: suppressed %r" % exc, file=sys.stderr)
        report_alert("patrol runner crashed: %s" % exc, "patrol:runner",
                     evidence=repr(exc))
        sys.exit(0)








