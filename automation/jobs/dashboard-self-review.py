#!/usr/bin/env python3
"""dashboard-self-review — one read-only tick: Hngh checks its own dashboard.

Procedural recognition of sufficient vs insufficient dashboard state
(operator directive 2026-08-27). Checks the served surfaces + feeds:

  1. freshness   sessions/operator-items (1m tier), time-ledger (5m),
                 readout (30m) — stale beyond STALE_MULT x tier = finding.
  2. validity    each feed parses; required keys present (sessions rows>0
                 OR explicit empty marker; time-ledger units>=1).
  3. served      dashboard pages return 200 and contain their expected
                 markers (catches served-stale / cached regressions).
  4. ledger      report-queue --json row count vs report-bodies file
                 count; drift > LEDGER_DRIFT_MAX = finding.

Every finding is classified per the two-tier vocabulary:
  unacceptable-now   immediate attention (stale 3x, invalid feed, missing
                     page marker) — detail names why.
  acceptable-for-now works, improvement planned — detail names it.

Findings land via `report-queue --add alert --identity
dash-selfreview:<check> --window 86400` so recurring findings collapse
into xN counts instead of spamming rows. All-clear ticks are silent.
Fail closed: unexpected errors degrade to a single unacceptable-now
finding, exit 0 always (a broken self-review must never break cadence).
"""

import json
import os
import subprocess
import sys
import time
import importlib.util
from importlib.machinery import SourceFileLoader
import urllib.error
import urllib.request
from pathlib import Path

# ---- operator-editable thresholds ------------------------------------
BASE_URL = os.environ.get("BASE_URL", "http://127.0.0.1:8890")
DASH_DIR = os.environ.get(
    "DASH_DIR", "/home/bricker/Projects/etc/hngh-automation/dashboard"
)
HNGH_REPO = os.environ.get("HNGH_REPO", "/home/bricker/Projects/etc/hngh")
STALE_MULT = 3          # feed is stale when older than N x its tier
LEDGER_DRIFT_MAX = 50   # |ledger rows - body files| tolerated
REPORT_WINDOW = "86400" # dedup window (s) for report-queue identities

# feed -> expected refresh tier (seconds)
FEED_TIERS = {
    "sessions.json": 60,
    "operator-items.json": 60,
    "time-ledger.json": 300,
    "readout.json": 1800,
}

# served file -> marker that must appear in the 200 body
PAGE_MARKERS = {
  "index.html": "verdict-pill",
    "sessions-view.js": "SessionsView",
    "sessions.js": "observatory",  # compat stub: meta-refresh to the nerve center
    "gantt.js": "ESTIMATE",
    "schedule-view.js": "ScheduleView",
    "app.js": "roster",
}
# -----------------------------------------------------------------------


def finding(check, unacceptable, detail):
    return {
        "check": check,
        "status": "unacceptable-now" if unacceptable else "acceptable-for-now",
        "detail": detail,
    }


def check_feed_fresh():
    f = []
    now = time.time()
    for name, tier in FEED_TIERS.items():
        p = Path(DASH_DIR) / name
        if not p.exists():
            f.append(finding(f"feed-fresh:{name}", True, f"{p} missing"))
            continue
        age = now - p.stat().st_mtime
        if age > STALE_MULT * tier:
            f.append(finding(
                f"feed-fresh:{name}", True,
                f"stale {int(age)}s > {STALE_MULT}x tier {tier}s — "
                f"producer for {name} is not firing or is failing"))
    return f


def check_feed_valid():
    f = []
    for name in FEED_TIERS:
        p = Path(DASH_DIR) / name
        try:
            d = json.loads(p.read_text())
        except Exception as e:
            f.append(finding(f"feed-valid:{name}", True, f"unparsable: {e}"))
            continue
        if not isinstance(d, dict):
            f.append(finding(f"feed-valid:{name}", True, "not a JSON object"))
            continue
        if name == "sessions.json":
            rows = d.get("sessions")
            if not isinstance(rows, list) or (
                not rows and not (d.get("empty") or d.get("note"))
            ):
                f.append(finding(
                    f"feed-valid:{name}", True,
                    "sessions rows==0 without explicit empty marker — "
                    "sessions-feed should emit one on empty rosters"))
        elif name == "operator-items.json":
            if not isinstance(d.get("items"), list):
                f.append(finding(f"feed-valid:{name}", True, "missing items[]"))
        elif name == "time-ledger.json":
            units = d.get("units")
            if not isinstance(units, list) or len(units) < 1:
                f.append(finding(
                    f"feed-valid:{name}", True,
                    "units<1 — time-ledger measured nothing; check "
                    "cadence/5m/00-time-ledger.sh"))
        elif name == "readout.json":
            missing = [k for k in ("timeline", "queue", "verdict") if k not in d]
            if missing:
                f.append(finding(
                    f"feed-valid:{name}", True,
                    f"missing spine keys: {','.join(missing)}"))
    return f


def check_served():
    f = []
    for name, marker in PAGE_MARKERS.items():
        try:
            with urllib.request.urlopen(f"{BASE_URL}/{name}", timeout=10) as r:
                body = r.read().decode("utf-8", "replace")
                code = r.status
        except (urllib.error.URLError, OSError) as e:
            f.append(finding(
                f"served:{name}", True,
                f"{BASE_URL}/{name} unreachable ({e}) — is "
                f"hngh-dashboard.service up?"))
            continue
        if code != 200:
            f.append(finding(f"served:{name}", True, f"HTTP {code}"))
        elif marker not in body:
            f.append(finding(
                f"served:{name}", True,
                f"marker {marker!r} absent from served body — served-stale "
                f"or cache regression (style.css ?v= class of bug)"))
    return f


def check_ledger():
    f = []
    rq = Path(HNGH_REPO) / "scripts" / "report-queue"
    try:
        out = subprocess.run(
            [str(rq), "--json"], capture_output=True, text=True,
            cwd=HNGH_REPO, timeout=30, check=True).stdout
        rows = len(json.loads(out).get("reports", []))
    except Exception as e:
        f.append(finding("ledger-sanity", True, f"report-queue --json failed: {e}"))
        return f
    bodies = len(list((Path(HNGH_REPO) / "docs/project/report-bodies").glob("*.md")))
    if abs(rows - bodies) > LEDGER_DRIFT_MAX:
        f.append(finding(
            "ledger-sanity", True,
            f"drift {abs(rows - bodies)} rows ({rows} ledger vs {bodies} "
            f"bodies) > {LEDGER_DRIFT_MAX} — queue panel would show rows "
            f"whose bodies are gone; reconcile/prune"))
    return f


def report(findings):
    """One deduped report row per check + a summary row, ×N on repeats."""
    # report-queue's --identity dedup only compares the NEWEST row of a
    # kind, so a tick filing several distinct identities never matches;
    # reuse its read_rows/row_identity/bump_row for true per-identity dedup.
    path = Path(HNGH_REPO) / "scripts" / "report-queue"
    loader = SourceFileLoader("report_queue", str(path))
    spec = importlib.util.spec_from_loader("report_queue", loader)
    rq = importlib.util.module_from_spec(spec)
    loader.exec_module(rq)

    def add_or_bump(ident, text):
        for r in reversed(rq.read_rows()):
            if (r[1] == "alert" and rq.row_identity(r) == ident
                    and rq.within_window(r[0], int(REPORT_WINDOW))):
                rq.bump_row(r, rq.now_ts())
                return
        rq.add("alert", text, identity=ident, window=int(REPORT_WINDOW))

    for x in findings:
        text = f"[dash-selfreview] {x['check']}: {x['status']} — {x['detail']}"
        add_or_bump(f"dash-selfreview:{x['check']}", text)
    u = sum(1 for x in findings if x["status"] == "unacceptable-now")
    a = len(findings) - u
    add_or_bump(
        "dash-selfreview:summary",
        f"[dash-selfreview] summary: {len(findings)} findings "
        f"({u} unacceptable-now, {a} acceptable-for-now)")
    for x in findings:
        print(f"{x['check']}: {x['status']} — {x['detail']}", file=sys.stderr)
    print(f"dashboard-self-review: {len(findings)} findings "
          f"({u} unacceptable-now, {a} acceptable-for-now)", file=sys.stderr)


def main():
    try:
        findings = (check_feed_fresh() + check_feed_valid()
                    + check_served() + check_ledger())
    except Exception as e:  # fail closed: the tick itself never breaks cadence
        findings = [finding("self-review", True, f"tick crashed: {e!r}")]
    if findings:
        report(findings)
    # all-clear ticks are silent
    return 0


if __name__ == "__main__":
    sys.exit(main())
