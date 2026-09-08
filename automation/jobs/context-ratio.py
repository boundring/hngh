#!/usr/bin/env python3
"""context-ratio — the context manager's weekly vital sign (hngh
docs/design/context-manager.md, measurement loop).

Reads the last 7 days of telemetry kind=session-cost rows (per-session
tokens_in/tokens_out, captured hourly by cadence/hour/25-session-cost.sh),
computes per-session in:out ratios, and files ONE identity-deduped
report-queue progress row (identity context-ratio:<date>, window 1 day):
sessions counted, median ratio paid vs local, worst session, and the trend
vs the previous context-ratio row (parsed from the report queue; "first
run" when none exists). Model-free and deterministic: sqlite aggregates
plus arithmetic, no LLM call. Targets (designed, not enforced here):
paid toward <=10:1, local toward <=50:1, measured weekly.

Paid/local split: a session is paid when its dominant model is the paid
GLM leg (model string containing "glm" or a zai/z-ai prefix), local
otherwise — the two buckets the 2026-09-07 session-cost analysis tracks.

Env seams (tests): HNGH_TELEMETRY_DB, HNGH_REPORT_ROOT, HNGH_TICK_TS
(UTC date), HNGH_HOME (kernel repo hosting scripts/report-queue).
Fail-closed: prints a one-line summary, exit 0 always — telemetry can
never fail a tick.
"""
import os
import re
import sqlite3
import sys
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KERNEL = os.environ.get("HNGH_HOME") or os.path.join(
    os.path.expanduser("~"), "Projects", "etc", "hngh")
DB = os.environ.get("HNGH_TELEMETRY_DB") or os.path.join(
    ROOT, "dashboard", "telemetry.db")
REPORT_ROOT = os.environ.get("HNGH_REPORT_ROOT") or KERNEL
DAY = os.environ.get("HNGH_TICK_TS") or __import__("time").strftime(
    "%Y-%m-%d", __import__("time").gmtime())

WINDOW_DAYS = 7
IDENTITY = "context-ratio:"


def is_paid(model):
    m = (model or "").lower()
    return "glm" in m or m.startswith(("zai/", "z-ai/"))


def median(vals):
    if not vals:
        return None
    v = sorted(vals)
    n = len(v)
    return v[n // 2] if n % 2 else (v[n // 2 - 1] + v[n // 2]) / 2.0


def ratios():
    """[(ratio, model)] for the last 7 days of session-cost rows."""
    try:
        conn = sqlite3.connect("file:%s?mode=ro" % DB, uri=True, timeout=10)
        try:
            rows = conn.execute(
                "select model, tokens_in, tokens_out from events"
                " where kind='session-cost' and ts >= date('now','-%d days')"
                " and tokens_in is not null and tokens_out is not null"
                " and tokens_in > 0 and tokens_out > 0"
                % WINDOW_DAYS).fetchall()
        finally:
            conn.close()
    except Exception:
        return []
    return [(tin / tout, model or "?") for model, tin, tout in rows]


def load_report_queue():
    path = os.path.join(KERNEL, "scripts", "report-queue")
    loader = SourceFileLoader("report_queue_ctx", path)
    spec = spec_from_loader("report_queue_ctx", loader)
    mod = module_from_spec(spec)
    os.environ["HNGH_REPORT_ROOT"] = REPORT_ROOT
    loader.exec_module(mod)
    return mod


def previous_row(rq):
    """First line of the newest context-ratio row that is NOT today's."""
    for row in reversed(rq.read_rows()):  # newest first
        if rq.row_identity(row) == IDENTITY + DAY:
            continue  # today's own row (re-run bump)
        ident = rq.row_identity(row) or ""
        if ident.startswith(IDENTITY):
            return row[3]
    return None


def trend_line(prev_first, paid, local):
    """'paid A->B (dir), local C->D (dir)' from the previous row."""
    def field(text, key):
        m = re.search(key + r"=([\d.]+)", text or "")
        return m.group(1) if m else None

    def fmt(x):
        return "none" if x is None else "%.1f" % x

    def arrow(new, old):
        if new is None or old is None:
            return "n/a"
        return ("down" if new < old else
                "up" if new > old else "flat")

    p0 = field(prev_first, "paid_median")
    l0 = field(prev_first, "local_median")
    try:
        p0 = float(p0) if p0 else None
        l0 = float(l0) if l0 else None
    except ValueError:
        p0 = l0 = None
    return "paid %s->%s (%s), local %s->%s (%s)" % (
        fmt(p0), fmt(paid), arrow(paid, p0),
        fmt(l0), fmt(local), arrow(local, l0))


def main():
    rs = ratios()
    paid = median([r for r, m in rs if is_paid(m)])
    local = median([r for r, m in rs if not is_paid(m)])
    if not rs:
        print("context-ratio: no session-cost rows with tokens; nothing filed")
        return
    worst_r, worst_m = max(rs, key=lambda t: t[0])
    rq = load_report_queue()
    prev = previous_row(rq)
    trend = "first run" if prev is None else trend_line(prev, paid, local)
    text = ("context-ratio %s: sessions=%d paid_median=%s local_median=%s "
            "worst=%.1f (%s) trend: %s" % (
                DAY, len(rs),
                "none" if paid is None else "%.1f" % paid,
                "none" if local is None else "%.1f" % local,
                worst_r, worst_m, trend))
    rc = rq.add("progress", text, IDENTITY + DAY, 86400)
    print("context-ratio: filed(rc=%d) %s" % (rc, text))


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # fail-closed: never fail a tick
        print("context-ratio: skipped (%s)" % exc)
    sys.exit(0)
