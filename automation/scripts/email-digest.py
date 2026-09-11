#!/usr/bin/env python3
"""email-digest — compose the daily operator digest (transport-agnostic).

The cadence drop-in (cadence/day/09-email-digest.sh) supplies live data;
every gather has an env seam so tests feed fixtures and never run git,
sqlite, or SMTP:
  HNGH_DIGEST_KERNEL_COMMITS / HNGH_DIGEST_AUTO_COMMITS  git log text
  HNGH_DIGEST_RESEARCH      git status --porcelain text (untracked docs)
  HNGH_DIGEST_PLANS         plans.json path
  HNGH_DIGEST_TELEMETRY     pre-rendered telemetry-report text
  HNGH_HOME / HNGH_AUTOMATION_ROOT  repo roots (kernel research docs)
Prints the digest markdown on stdout; exits 0 even when a gather is
empty (a thin section is data, not failure).

Reading order is operator-first: a 3-line TL;DR (status / what changed /
spend + action needed), then operator items, progress, research,
commits, alerts, budget, footer. Any section that could exceed ~6 lines
states its facts directly (no self-description). Output is ASCII plain
text, every line wrapped at 78 columns.

Redaction duty (credentials-posture.md §4): before printing, the digest
is passed through redact(), which compare-and-redacts anything matching
the conf's smtp `pass` value (read via the HNGH_NOTIFY_EMAIL_CONF seam).
The secret value is never printed, logged, or echoed — only compared.
"""
import configparser
import glob
import html
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timedelta, timezone

AUTOMATION = os.environ.get(
    "HNGH_AUTOMATION_ROOT",
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
KERNEL = os.environ.get("HNGH_HOME",
                        os.path.expanduser("~/Projects/etc/hngh"))
DAY_24H = 86400
ALERT_WINDOW_S = 7 * DAY_24H
PLAN_ROW = re.compile(r"^\s+(\S+)\s+(\S+)\s+steps\s+(\d+)/(\d+)")
SPEND_RE = re.compile(r"session-cost total: \$([0-9.]+)")
PLAN_CAP = 15  # live plans listed before the dashboard pointer kicks in


def git_log(root):
    env = os.environ.get(
        "HNGH_DIGEST_KERNEL_COMMITS" if root == KERNEL
        else "HNGH_DIGEST_AUTO_COMMITS")
    if env is not None:
        return env
    if not os.path.isdir(os.path.join(root, ".git")):
        return "(no git repository)"
    try:
        p = subprocess.run(
            ["git", "-C", root, "log", "--since=24 hours ago",
             "--oneline", "--no-decorate"],
            capture_output=True, text=True, timeout=30)
        return p.stdout.strip() or "(no commits in the last 24h)"
    except (OSError, subprocess.TimeoutExpired) as exc:
        return "(git log unavailable: %s)" % exc


def research_status():
    env = os.environ.get("HNGH_DIGEST_RESEARCH")
    if env is not None:
        return [l for l in env.splitlines() if l.strip()]
    rows = []
    try:
        p = subprocess.run(["git", "-C", AUTOMATION, "status", "--porcelain"],
                           capture_output=True, text=True, timeout=30)
        rows = [l for l in p.stdout.splitlines()
                if l.startswith("??") and "/docs/" in l]
    except (OSError, subprocess.TimeoutExpired):
        pass
    return rows


def parse_prev_plan_lines(path):
    """slug -> (status, done, total) from a previous digest's plan lines."""
    try:
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
    except OSError:
        return None  # (first digest)
    plans = {}
    for ln in text.splitlines():
        m = PLAN_ROW.match(ln)
        if m:
            plans[m.group(1)] = (m.group(2), int(m.group(3)), int(m.group(4)))
    return plans


def prev_digest_path():
    yesterday = (datetime.now(timezone.utc)
                 - timedelta(days=1)).strftime("%Y-%m-%d")
    return os.environ.get(
        "HNGH_DIGEST_PREV_DIGEST",
        os.path.join(AUTOMATION, "logs", "email-digest-%s.md" % yesterday))


def queued_count():
    """Kernel docs/project/queue.md rows whose status column is 'queued'
    (TSV, first row is the header; fence prose has no tabs)."""
    path = os.environ.get(
        "HNGH_DIGEST_QUEUE",
        os.path.join(KERNEL, "docs", "project", "queue.md"))
    try:
        with open(path, encoding="utf-8") as fh:
            rows = [ln.split("\t") for ln in fh.read().splitlines()]
    except OSError:
        return None
    return sum(1 for r in rows
               if len(r) >= 4 and r[0].strip() != "id" and r[1].strip() == "queued")


def plan_supply(plans):
    """Accepted plans that still have unchecked steps."""
    return sum(1 for p in plans
               if p.get("status") == "accepted"
               and p.get("steps_done", 0) < p.get("steps_total", 0))


def routed_one_steppers(plans):
    """'routed one-steppers: N accepted, M executed (24h)' — the router's
    per-alert candidates (2026-09-04 digest: 10 accepted agent-stall
    one-steppers sat at 0/1). plans.json carries no timestamps, so the
    slug's date prefix vs today/yesterday is the cheapest honest 24h
    window. None when plans are unreadable (the line is skipped)."""
    if plans is None:
        return None
    now = datetime.now(timezone.utc)
    days = {now.strftime("%Y-%m-%d"),
            (now - timedelta(days=1)).strftime("%Y-%m-%d")}
    acc = exc = 0
    for p in plans:
        slug = p.get("slug", "")
        if (p.get("steps_total", 0) != 1 or "-routed-" not in slug
                or slug[:10] not in days):
            continue
        if p.get("status") == "accepted":
            acc += 1
        elif p.get("status") == "executed":
            exc += 1
    return "routed one-steppers: %d accepted, %d executed (24h)" % (acc, exc)


def queue_progress():
    """'Queue progress (24h)': live-plan step deltas vs yesterday's digest,
    the kernel queue.md queued count, and the plan-supply line. Env seams
    for tests: HNGH_DIGEST_PLANS / HNGH_DIGEST_PREV_DIGEST /
    HNGH_DIGEST_QUEUE."""
    try:
        with open(os.environ.get(
                "HNGH_DIGEST_PLANS",
                os.path.join(AUTOMATION, "dashboard", "plans.json")),
                encoding="utf-8") as fh:
            plans = json.load(fh).get("plans", [])
    except (OSError, ValueError):
        plans = None  # this gather degrades; the counts still report

    prev_path = prev_digest_path()
    prev = parse_prev_plan_lines(prev_path)

    total_delta = 0
    rows = []
    for p in plans or []:
        if p.get("status") in ("executed", "rejected"):
            continue  # only live plans interest the operator
        slug, done = p.get("slug", "?"), p.get("steps_done", 0)
        total = p.get("steps_total", 0)
        delta = ""
        if prev is None:
            delta = " (first digest)"
        elif slug in prev:
            d = done - prev[slug][1]
            delta = " (+%d)" % d if d >= 0 else " (%d)" % d
            total_delta += d
        else:
            delta = " (new)"
        moved = prev is None or slug not in prev or d != 0
        rows.append(((0 if moved else 1, slug),
                     "  %-32.32s %-9.9s steps %s/%s%s" % (
            slug, p.get("status", "?"), done, total, delta)))
    rows.sort(key=lambda r: r[0])  # movers first; unchanged plans overflow
    lines = [l for _k, l in rows]
    if len(lines) > PLAN_CAP:
        lines = lines[:PLAN_CAP] + [
            "  (+%d more live plan(s) — full state in the dashboard)"
            % (len(lines) - PLAN_CAP)]
    if plans is None:
        lines.append("  (plans.json unreadable)")
    elif not lines:
        lines.append("  (all plans executed/rejected)")
    nq = queued_count()
    lines.append("kernel queue: %s queued rows" % ("%d" % nq if nq is not None else "unreadable"))
    lines.append("plan-supply: %d accepted plans with unchecked steps"
                 % (plan_supply(plans) if plans is not None else 0))
    held = sum(1 for p in plans or [] if p.get("status") == "held") \
        if plans is not None else 0
    if held:
        lines.append("%d plan%s held (missing design)"
                     % (held, "" if held == 1 else "s"))
    one_steppers = routed_one_steppers(plans)
    if one_steppers:
        lines.append(one_steppers)
    pending = plan_supply(plans) if plans is not None else 0
    return "\n".join(lines), total_delta, pending


def pace(delta, have_prev, pending):
    """One-line verdict from the delta math + pending supply. Rubric fix
    (2026-09-04 digest said "steady" on a 0-step day while 40 accepted
    plans sat unchecked): 0 ticks with pending accepted work is
    STALLING, not steady; 0 ticks with an empty queue is idle."""
    if not have_prev:
        return "pace: first digest (no prior digest to diff)"
    if delta > 0:
        return "pace: rising (+%d steps in 24h)" % delta
    if delta < 0:
        return "pace: stalling (%d steps in 24h)" % delta
    if pending > 0:
        return "pace: stalling (0 steps in 24h; %d plans pending)" % pending
    return "pace: idle (queue empty)"


def lessons():
    d = os.path.join(KERNEL, "docs", "project")
    newest = ""
    try:
        for name in sorted(os.listdir(d)):
            if name.startswith("lessons-") and name.endswith(".md"):
                newest = name  # sorted: latest date last
    except OSError:
        pass
    if not newest:
        return "(no lesson harvest found)"
    try:
        with open(os.path.join(d, newest), encoding="utf-8", errors="replace") as fh:
            n = sum(1 for _ in fh)
    except OSError:
        n = 0
    return "%s (%d lines)" % (newest, n)


def budget():
    env = os.environ.get("HNGH_DIGEST_TELEMETRY")
    if env:
        return env
    try:
        p = subprocess.run(
            [sys.executable, os.path.join(AUTOMATION, "jobs",
                                          "telemetry-report.py")],
            capture_output=True, text=True, timeout=60)
        return p.stdout.strip() or p.stderr.strip() or "(telemetry empty)"
    except (OSError, subprocess.TimeoutExpired) as exc:
        return "(telemetry-report unavailable: %s)" % exc


def budget_lines(cap=12):
    """Budget section body: the telemetry text capped at `cap` lines —
    spend + trend is the operator ask; the full report lives in the
    dashboard (and would blow the <120-line digest budget)."""
    lines = [l for l in budget().splitlines()]
    if len(lines) <= cap:
        return "\n".join(lines)
    return "\n".join(lines[:cap]) + "\n  (+%d more lines — full report in the dashboard)" % (
        len(lines) - cap)



def classify_alerts(rows):
    """Classify alert rows into critical/notable/info tiers.
    Critical: mentions 'P0', 'gate-red', 'blocked', 'failed' (rc=2).
    Notable: mentions 'escalated', 're-occurred', 'stall', 'router dedup escalation'.
    Info: everything else.
    Returns dict with 'critical', 'notable', 'info' lists."""
    critical_re = re.compile(r'(P0|gate-red|blocked|FAILED\s+\(rc=2\))', re.I)
    notable_re = re.compile(r'(escalated|re-occurred|stall|router dedup escalation)', re.I)
    critical, notable, info = [], [], []
    for r in rows:
        if critical_re.search(r):
            critical.append(r)
        elif notable_re.search(r):
            notable.append(r)
        else:
            info.append(r)
    return {'critical': critical, 'notable': notable, 'info': info}


def dedup_alerts(rows):
    """Fold suppressed/escalated variants into unique alerts.
    Returns list of unique alert lines with dedup counts as suffix.
    Strategy: group by normalized key (strip router/escalated/dedup prefixes)."""
    seen = {}
    for r in rows:
        # Normalize: strip 'router dedup:', 'router dedup escalation:', 'router escalated:'
        key = r
        for prefix in ['router dedup escalation: ', 'router dedup: ', 'router escalated: ']:
            if r.startswith(prefix):
                key = r[len(prefix):]
                break
        # Also strip 'router dedup escalation' prefix (no colon)
        if 'router dedup escalation: ' in r:
            key = r.split('router dedup escalation: ')[1]
        elif 'router dedup: ' in r:
            key = r.split('router dedup: ')[1]
        elif 'router escalated: ' in r:
            key = r.split('router escalated: ')[1]
        if key in seen:
            seen[key]['count'] += 1
        else:
            seen[key] = {'line': r, 'count': 1}
    out = []
    for k, v in seen.items():
        if v['count'] > 1:
            out.append('%s (×%d)' % (v['line'], v['count']))
        else:
            out.append(v['line'])
    return out



def alert_rows(window_s=ALERT_WINDOW_S):
    """Alert report-queue rows from the last window_s seconds (default
    7d; env seam for tests: HNGH_DIGEST_ALERTS = pre-rendered lines,
    one per row — fixture rows carry no timestamps and count as
    in-window)."""
    env = os.environ.get("HNGH_DIGEST_ALERTS")
    rows = []
    if env is not None:
        rows = [l for l in env.splitlines() if l.strip()]
    else:
        try:
            p = subprocess.run(
                [sys.executable, os.path.join(KERNEL, "scripts",
                                              "report-queue"), "--json"],
                capture_output=True, text=True, timeout=30)
            if p.returncode == 0:
                cutoff = time.time() - window_s
                for r in json.loads(p.stdout).get("reports", []):
                    try:
                        ts = datetime.strptime(r.get("ts", ""),
                                               "%Y-%m-%dT%H:%M:%SZ")
                    except ValueError:
                        continue
                    if r.get("kind") == "alert" \
                            and ts.replace(tzinfo=timezone.utc).timestamp() \
                            >= cutoff:
                        rows.append(r.get("first", ""))
        except (OSError, ValueError, subprocess.TimeoutExpired):
            pass
    return rows


def open_runs():
    """Overnight/delegated runs whose bridge-store record is still open
    (newest :STATE non-terminal; env seam HNGH_DIGEST_STORE_DIR)."""
    store = os.environ.get("HNGH_DIGEST_STORE_DIR",
                           os.path.expanduser("~/.hngh-automation/store"))
    terminal = {"cancelled", "evacuated", "dead", "complete"}
    open_rows = []
    try:
        for rec in glob.glob(os.path.join(store, "*", "record.lisp")):
            state, objective = "", ""
            with open(rec, encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    m = re.search(r":STATE :(\w+)", line)
                    if m:
                        state = m.group(1).lower()
                    if not objective:
                        m = re.search(r':OBJECTIVE "([^"]{0,70})', line)
                        if m:
                            objective = m.group(1)
            if state and state not in terminal:
                open_rows.append("%s %s" % (
                    os.path.basename(os.path.dirname(rec)), objective))
    except OSError:
        pass
    if not open_rows:
        return []
    out = ["  overnight runs still open: %d" % len(open_rows)]
    out += ["    " + r for r in open_rows[:3]]
    return out


def operator_items():
    """'Operator items awaiting you' — everything the operator must act
    on, one compact section (env seams mirror the other gathers:
    HNGH_NOTIFY_EMAIL_CONF, HNGH_DIGEST_ALERTS, HNGH_DIGEST_STORE_DIR)."""
    lines = []
    # (a) the email setup command itself, when the config is absent
    conf = os.environ.get(
        "HNGH_NOTIFY_EMAIL_CONF",
        os.path.expanduser("~/.hngh-automation/notify-email.conf"))
    if not os.path.isfile(conf):
        lines.append("  email channel dormant — one-command setup:")
        lines.append("    bash %s/scripts/setup-notify-email.sh" % AUTOMATION)
    # (b) machine-drafted plans awaiting review (newest first)
    drafts = []
    try:
        for name in os.listdir(os.path.join(AUTOMATION, "digest")):
            m = re.fullmatch(r"DRAFT-PLAN-(\d{4}-\d{2}-\d{2})\.md", name)
            if m:
                drafts.append((m.group(1), name))
    except OSError:
        pass
    for day, name in sorted(drafts, reverse=True)[:3]:
        status = "drafted"
        try:
            with open(os.path.join(AUTOMATION, "digest", name),
                      encoding="utf-8", errors="replace") as fh:
                m = re.search(r"plan: status=(\S+)", fh.read(400))
            if m:
                status = m.group(1)
        except OSError:
            pass
        lines.append("  draft plan %s (status=%s) — review: digest/%s"
                     % (day, status, name))
    # (c) alert rows, last 7 days   (d) overnight runs still open
    rows = alert_rows()
    if rows:
        lines.append("  alerts (last 7d): %d row(s), newest:" % len(rows))
        lines += ["    " + (r[:70] + "…" if len(r) > 70 else r)
                  for r in rows[:3]]
    lines += open_runs()
    return "\n".join(lines) or "(nothing awaiting the operator)"


def compose():
    day = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    tel = budget()
    alerts24 = alert_rows(window_s=DAY_24H)
    prog, delta, pending = queue_progress()
    items = operator_items()
    action = action_item(items)
    spend_t, spend_y = spend_today(tel), spend_yesterday()
    klines = commit_lines(git_log(KERNEL))
    alines = commit_lines(git_log(AUTOMATION))
    ktop, atop = klines[:5], alines[:5]
    more = max(0, len(klines) - 5) + max(0, len(alines) - 5)
    n_commits = sum(1 for l in klines + alines
                    if re.match(r"^[0-9a-f]{7,}\b", l))
    fresh, untracked = research_recent(), research_status()
    have_prev = os.path.isfile(prev_digest_path())

    out = ["# hngh daily digest %s" % day, ""]
    # (1) HEADLINE — the operator's first three seconds
    out.append("status: %s" % (
        "ATTENTION: %d alert(s) in 24h" % len(alerts24) if alerts24 else "OK"))
    out.append("changed: %d commit(s), %+d plan steps in 24h, "
               "%d research doc(s) crystallized" % (n_commits, delta, len(fresh)))
    spend = ("spend: %s today (vs %s yesterday; target $10/day)"
             % ("$" + spend_t if spend_t else "unknown",
                "$" + spend_y if spend_y else "unknown"))
    if not spend_t and not spend_y:
        spend = "spend: no cost data in telemetry (target $10/day)"
    out.append(spend)
    out.append("action needed: %s" % (("yes — " + action) if action else "no"))
    out.append("")
    # (2) OPERATOR ITEMS AWAITING YOU
    out.append("## Operator items awaiting you")
    out.append(items)
    out.append("")
    # (3) PROGRESS
    out.append("## Progress (plans + queue, 24h)")
    out.append(prog)
    out.append(pace(delta, have_prev, pending))
    out.append("")
    # (4) RESEARCH
    out.append("## Research")
    out.append("crystallized (kernel docs/research, 24h):")
    out.append("\n".join(fresh) or "  (none in the last 24h)")
    out.append("untracked pending crystallization (automation):")
    out.append("\n".join(untracked) or "  (none)")
    out.append("lessons harvested: %s" % lessons())
    night = night_brief_line()
    if night:
        out.append(night)
    out.append("")
    # (5) COMMITS
    out.append("## Commits (24h)")
    out.append("%d commit(s) across both repos — kernel %d, automation %d."
               % (n_commits, len(ktop), len(atop)))
    out.append("kernel:")
    out += [ellipsize(l) for l in ktop] or ["  (none)"]
    out.append("automation:")
    out += [ellipsize(l) for l in atop] or ["  (none)"]
    if more:
        out.append("+%d more — full list: logs/email-digest-%s.md" % (more, day))
    out.append("")
    # (6) ALERTS
    out.append("## Alerts (last 24h)")
    if alerts24:
        classified = classify_alerts(alerts24)
        deduped = dedup_alerts(alerts24)
        out.append("%d alert(s) in the last 24h — %d critical, %d notable, %d info."
                   % (len(alerts24), len(classified['critical']),
                      len(classified['notable']), len(classified['info'])))
        out += [ellipsize(r) for r in deduped]
    else:
        out.append("none — quiet window")
    out.append("")
    # (7) BUDGET
    out.append("## Budget (telemetry)")
    if spend_t:
        out.append("$%s today vs target $10/day." % spend_t)
    bench = model_bench_line()
    if bench:
        out.append(bench)
    out.append(budget_lines())
    out.append("")
    # (8) FOOTER
    out += ["--",
            "full digest: logs/email-digest-%s.md | "
            "dashboard: http://127.0.0.1:8890" % day,
            "Form not rendering? Open the dashboard and use its feedback pip.",
           ]
    return wrap78(redact("\n".join(out))) + "\n"


def action_item(items_text):
    """The one operator action, or None. Alert previews are information,
    not action; setup, draft plans, and open runs need the operator."""
    for ln in items_text.splitlines():
        s = ln.strip()
        if s.startswith(("email channel dormant", "draft plan",
                         "overnight runs still open")):
            return s
    return None


def spend_today(telemetry_text):
    """Today's $ figure from the telemetry text already gathered
    (telemetry-report.py prints 'session-cost total: $X' when the db
    carries cost data)."""
    found = None
    for found in SPEND_RE.finditer(telemetry_text or ""):
        pass
    return found.group(1) if found else None


def spend_yesterday():
    """Prior-day spend, parsed from the previous digest's spend line."""
    try:
        with open(prev_digest_path(), encoding="utf-8", errors="replace") as fh:
            for ln in fh:
                if ln.lstrip().startswith("spend:"):
                    m = re.search(r"\$([0-9.]+)", ln)
                    if m:
                        return m.group(1)
    except OSError:
        pass
    return None


def commit_lines(text):
    return [l for l in (text or "").splitlines() if l.strip()]


def ellipsize(text, width=76):
    """One line, ≤78 cols: list items (commits, alerts) are truncated,
    never wrapped — a wrapped one-liner reads as two rows."""
    text = "  " + (text or "").strip()
    return text if len(text) <= width + 2 else text[:width] + "…"


def _config_env(name):
    """Bash-style default from config.env: NAME="${NAME:-value}"."""
    try:
        with open(os.path.join(AUTOMATION, "config.env"), encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return ""
    m = re.search(r'^%s="?\$\{%s:-(?P<v>[^}"]+)\}' % (name, name), text, re.M)
    return m.group("v") if m else ""


def dashboard_base_url():
    """http://host:port for the feedback action URL. Env wins (lib/common.sh
    sources config.env and exports the effective values), else the
    config.env default line, else the documented 8890. A 0.0.0.0 bind
    address is not addressable in a form action, so it renders as
    127.0.0.1 — LAN/phone operators open the dashboard URL from the footer
    pointer; a hardcoded LAN IP would rot across networks.
    """
    port = os.environ.get("DASHBOARD_PORT") or _config_env("DASHBOARD_PORT") or "8890"
    host = os.environ.get("DASHBOARD_HOST") or _config_env("DASHBOARD_HOST") or ""
    if host in ("", "0.0.0.0"):
        host = "127.0.0.1"
    return "http://%s:%s" % (host, port)


def feedback_form_html():
    """Compact HTML feedback form (one per email, not per section) feeding
    the SAME capture endpoint the dashboard pips use: POST /api/feedback,
    application/x-www-form-urlencoded (email is JS-free; the endpoint
    accepts both encodings). Email-safe: inline styles only, no JS, no
    external assets. NOTE: several clients strip <form> elements entirely
    (Outlook desktop, Gmail webmail, Apple Mail) — the plain-text fallback
    line under the form is mandatory, never remove it.
    """
    url = dashboard_base_url() + "/api/feedback"
    box = "border:1px solid #aaa;padding:4px;margin:2px 0;width:95%%;font-family:monospace;font-size:13px"
    return (
        '<form method="POST" action="%s" '
        'style="border:1px solid #ccc;padding:6px;margin:8px 0;'
        'font-family:monospace;font-size:13px">'
        '<div style="margin:4px 0">Feedback type: '
        '<select name="type" style="%s">'
        '<option>css-theme</option><option>data-format</option>'
        '<option>correction</option><option>idea</option></select></div>'
        '<input name="element" maxlength="80" '
        'placeholder="element/topic (one line)" style="%s"><br>'
        '<textarea name="text" maxlength="2000" rows="4" '
        'placeholder="your feedback" style="%s"></textarea><br>'
        '<button type="submit" style="padding:4px 10px">Submit feedback</button>'
        '<div style="margin-top:6px;color:#666">'
        "Form not rendering? Open the dashboard and use its feedback pip.</div>"
        "</form>"
    ) % (html.escape(url), box, box, box)


def wrap78(text):
    """Hard width cap: wrap every line at 78 columns (continuations
    indented two spaces) — the digest must read in any mail client."""
    out = []
    for ln in text.splitlines():
        while len(ln) > 78:
            cut = ln.rfind(" ", 0, 78)
            cut = cut if cut > 2 else 78
            out.append(ln[:cut])
            ln = "  " + ln[cut:].lstrip()
        out.append(ln)
    return "\n".join(out)


def redact(text):
    """Redaction duty (credentials-posture.md §4): strip anything
    matching the conf's smtp `pass` value. Compare-and-redact only —
    the secret value itself is never printed or logged."""
    conf = os.environ.get(
        "HNGH_NOTIFY_EMAIL_CONF",
        os.path.expanduser("~/.hngh-automation/notify-email.conf"))
    try:
        cp = configparser.ConfigParser()
        cp.read(conf)
        secret = cp.get("smtp", "pass", fallback=None)
    except Exception:
        return text
    if secret and len(secret) >= 4 and secret in text:
        text = text.replace(secret, "[redacted]")
    return text


def research_recent():
    d = os.path.join(KERNEL, "docs", "research")
    out = []
    try:
        cutoff = time.time() - DAY_24H
        for name in sorted(os.listdir(d)):
            path = os.path.join(d, name)
            if os.path.isfile(path) and os.path.getmtime(path) >= cutoff:
                out.append("  " + name)
    except OSError:
        pass
    return out


def model_bench_line():
    """Today's fleet-bench best line (digest/BENCH-<day>.md) — the bench
    digest's consumer. Empty when no bench ran today."""
    env = os.environ.get("HNGH_DIGEST_BENCH")
    if env is not None:
        return env.strip()
    day = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    try:
        with open(os.path.join(AUTOMATION, "digest",
                               "BENCH-%s.md" % day)) as fh:
            return next((l.strip() for l in fh if l.startswith("Best: ")), "")
    except OSError:
        return ""


def night_brief_line():
    """Today's night-research brief headline (digest/RESEARCH-<day>.md)
    with a pointer — the brief's consumer. Empty when no brief today."""
    day = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    path = os.path.join(AUTOMATION, "digest", "RESEARCH-%s.md" % day)
    try:
        with open(path) as fh:
            title = next((l.lstrip("# ").strip() for l in fh
                          if l.startswith("# ")), "")
    except OSError:
        return ""
    return "night brief: %s (digest/RESEARCH-%s.md)" % (title, day) \
        if title else ""


if __name__ == "__main__":
    if "--html" in sys.argv[1:]:
        # HTML alternative part for the email transport: the digest text
        # pre-escaped plus the feedback form. Same content, one extra cheap
        # compose; keeps this script the single source of the digest body.
        sys.stdout.write(
            '<!doctype html><html><head><meta charset="utf-8">'
            "<title>hngh daily digest</title></head>"
            '<body style="font-family:monospace;font-size:13px">'
            '<pre style="white-space:pre-wrap;margin:0">%s</pre>%s</body></html>'
            % (html.escape(compose()), feedback_form_html()))
    else:
        sys.stdout.write(compose())
