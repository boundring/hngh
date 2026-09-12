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
import json
import os
import re
import subprocess
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)  # automation/
REPO = os.path.dirname(ROOT)  # the hngh repo (kernel home)

FEEDS = [("plans.json", 3600), ("operator-items.json", 600),
         ("sessions.json", 600)]  # tier-scaled: 30m feed vs 1m feeds
HANDOFFS_LAST_N = 10
HANDOFFS_THRESHOLD = 3
GATE_STALE_HOURS = 26  # the day gate runs once a day; 24h + one tier slack
DISK_PCT = 90
RESEARCH_STALL_HOURS = 48
STUCK_STATES = ("planned", "expanding", "contracting")
DECK_ITEM_RE = re.compile(r"^(CRITICAL|NOTABLE|CONTEXT):")
DECK_BLOCK_RE = re.compile(r"^## \d{4}\b")


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
    gate-green/gate-red crumbs per label; the newest one decides, and a
    gate with no crumb in 26h is stale."""
    out = {"passes": [], "fails": []}
    label = ctx["gate_label"]
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
    _, event, detail = rows[-1]
    age_h = (ctx["now"] - rows[-1][0]) / 3600.0
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
    path = os.path.join(ctx["root"], "digest",
                        "%s.md" % ctx["date"])
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
    "session-budget": check_session_budget,
    "loop-history-guard": check_loop_history_guard,
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
            "PATROL_DIGEST_DIR", os.path.join(root, "digest")),
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
    """One run section, publication-review two-pass format."""
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
                       % (r["id"], artifact, cause, detail))
        if not r["fails"]:
            out.append("- ok %s -- no red findings" % r["id"])
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


def report_alert(text, identity):
    """report-queue alert; best-effort (a lost queue write is a stderr
    line, never a crash)."""
    bin_path = os.environ.get(
        "REPORT_QUEUE_BIN", os.path.join(REPO, "scripts", "report-queue"))
    env = dict(os.environ,
               HNGH_REPORT_ROOT=os.environ.get("PATROL_REPORT_ROOT", REPO))
    try:
        r = subprocess.run([bin_path, "--add", "alert",
                            text, "--identity", identity,
                            "--window", "86400"],
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
    ap.add_argument("--repo", default=os.environ.get("PATROL_ROOT", ROOT))
    ap.add_argument("--kernel", default=os.environ.get("PATROL_KERNEL", REPO))
    args = ap.parse_args(argv)
    now_s = float(os.environ.get("PATROL_NOW_EPOCH", time.time()))
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
                         "patrol:" + pid)
        queued = queue_repeat_subjects(
            ctx, prev_runs[-1] if prev_runs else [],
            [(pid, cause) for pid, (a, cause, d) in fails])
        for rid in queued:
            print("QUEUED research-subject %s" % rid)
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
        report_alert("patrol runner crashed: %s" % exc, "patrol:runner")
        sys.exit(0)








