#!/usr/bin/env python3
"""newspaper email HTML — the operator digest's HTML alternative part.

Email-safe constraint set (documented; differs from jobs/digest-html.py):
  - No JS, no external assets, no <style> in <head>: Gmail strips head
    styles and blocks remote images, Outlook strips <svg> — ALL styling
    is inline on each element and layout is nested tables (the only
    grid primitive every client honors). Nested-table depth is capped
    at 3 (tested).
  - Sparklines are UNICODE BLOCK GLYPHS (U+2581..U+2588, one char per
    hourly bucket, deterministic stdlib mapping) inside a monospace
    cell — SVG is unreliable in email, block characters are plain text.
  - Links: news items link their URLs; plan rows link the dashboard
    when it answers (TCP probe, 1s); form action from the shared
    dashboard_base_url. The hidden hngh_token field contract is
    untouched (docs/records/2026-09-11-dashboard-p1-server.md).
Palette: display-register tokens (dashboard/style.css) inlined: bg
#0d1117, panel #161b22, line #30363d, ink #e6edf3, moss #7FA05E, bone
#e7e2d3, warn #d29922, ash #99a3ae.

usage (module): render_html(g) -> str; g is email_digest.gather().
"""
import html
import importlib.util
import os
import re
import socket
import sqlite3
import sys
from datetime import datetime, timedelta, timezone
from urllib.parse import urlsplit

SCRIPTS = os.path.dirname(os.path.abspath(__file__))
AUTOMATION = os.environ.get(
    "HNGH_AUTOMATION_ROOT",
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

C_BG, C_PANEL, C_LINE = "#0d1117", "#161b22", "#30363d"
C_INK, C_ASH = "#e6edf3", "#99a3ae"
C_MOSS, C_BONE, C_WARN = "#7FA05E", "#e7e2d3", "#d29922"

# U+2581..U+2588: 8 rungs, index = intensity 0..7
BLOCKS = "\u2581\u2582\u2583\u2584\u2585\u2586\u2587\u2588"


_DIGEST_MOD = None


def digest_module():
    """The plain-text composer (scripts/email-digest.py) — reused, not
    duplicated: its gathers, parsers, and form builder are this email's
    data layer."""
    global _DIGEST_MOD
    if _DIGEST_MOD is None:
        spec = importlib.util.spec_from_file_location(
            "email_digest", os.path.join(SCRIPTS, "email-digest.py"))
        _DIGEST_MOD = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_DIGEST_MOD)
    return _DIGEST_MOD


def esc(text):
    """HTML-escape, force ASCII (non-ASCII -> numeric entities)."""
    return html.escape(str(text), quote=True).encode(
        "ascii", "xmlcharrefreplace").decode("ascii")


def hourly_buckets(date, db=None):
    """24 hourly buckets for <date>: (hour, cost_usd, tokens_in, calls)
    from dashboard/telemetry.db (read-only; zero-filled like
    jobs/digest-html.telemetry_hourly). Empty when no db. Env seam
    HNGH_DIGEST_HOURLY="cost:tokens:calls,..." (tests/hermetic; zero-
    padded to 24 like the real query)."""
    env = os.environ.get("HNGH_DIGEST_HOURLY")
    if env is not None:
        got = []
        for i, part in enumerate(env.split(",")):
            c, t, n = part.split(":")
            got.append((i, float(c), int(t), int(n)))
        return got + [(h, 0.0, 0, 0) for h in range(len(got), 24)]
    db = db or os.path.join(AUTOMATION, "dashboard", "telemetry.db")
    if not os.path.isfile(db):
        return []
    try:
        conn = sqlite3.connect("file:%s?mode=ro" % db, uri=True, timeout=5)
        rows = conn.execute(
            "SELECT CAST(substr(ts,12,2) AS INTEGER),"
            " SUM(COALESCE(cost_usd,0)), SUM(COALESCE(tokens_in,0)), COUNT(*)"
            " FROM events WHERE ts LIKE ? || 'T%'"
            " GROUP BY 1 ORDER BY 1", (date,)).fetchall()
        conn.close()
    except Exception:
        return []
    buckets = {h: (c, t, n) for h, c, t, n in rows}
    return [(h,) + buckets.get(h, (0.0, 0, 0)) for h in range(24)]


def sparkline_blocks(values):
    """(hour, value) pairs -> U+2581..U+2588 glyphs, one per bucket,
    linear map value/peak -> rung 0..7; zero-only data stays flat.
    Deterministic stdlib; replaces digest-html's SVG in email."""
    peak = max((v for _h, v, _n in values), default=0.0)
    out = []
    for _h, v, _n in values:
        out.append(BLOCKS[0] if peak <= 0 or v <= 0
                   else BLOCKS[min(7, int(v / peak * 7.999))])
    return "".join(out)


def prev_digest_path():
    """Same rule as the plain digest (email_digest's seam is private to
    its module state, so re-derive): yesterday's logs/email-digest."""
    yesterday = (datetime.now(timezone.utc)
                 - timedelta(days=1)).strftime("%Y-%m-%d")
    return os.environ.get(
        "HNGH_DIGEST_PREV_DIGEST",
        os.path.join(AUTOMATION, "logs", "email-digest-%s.md" % yesterday))


def delta_line(today_text):
    """'since yesterday' caption, or ''. Compares yesterday's digest
    file (if readable) against today's: new section headers + spend
    delta. Omitted when yesterday is unreadable — never invented."""
    try:
        with open(prev_digest_path(), encoding="utf-8") as fh:
            prev = fh.read()
    except OSError:
        return ""
    if not prev.strip():
        return ""
    prev_sec = re.findall(r"^## (.+)$", prev, re.M)
    added = [s for s in re.findall(r"^## (.+)$", today_text, re.M)
             if s not in prev_sec][:3]
    parts = []
    if added:
        parts.append("new section(s): %s" % ", ".join(added))
    m = re.search(r"spend: \$([0-9.]+) today", today_text)
    pm = re.search(r"spend: \$([0-9.]+) today", prev)
    if m:
        parts.append("metered spend $%s (was $%s)"
                     % (m.group(1), pm.group(1) if pm else "unknown"))
    return "since yesterday: %s" % "; ".join(parts) if parts else ""


SECTION_RE = re.compile(r"^## (\d{4}) (\d{4}-\d{2}-\d{2})\s*$")


def news_sections(text):
    """'## HHMM <date>' blocks from a daily digest (automation/digest/
    <date>.md): [{time, sources, model, items}] — the Outside World deck
    (parse mirrors jobs/digest-html.parse_sections)."""
    out, cur = [], None
    for line in text.splitlines():
        m = SECTION_RE.match(line)
        if m:
            cur = {"time": m.group(1), "sources": "", "model": "", "items": []}
            out.append(cur)
            continue
        if cur is None or not line.strip() or line.startswith("#"):
            continue
        if line.startswith("_sources: ") and line.endswith("_"):
            body = line[len("_sources: "):-1]
            if " | model: " in body:
                src, model = body.split(" | model: ", 1)
                cur["sources"], cur["model"] = src.strip(), model.strip(" _")
            else:
                cur["sources"] = body.strip()
        else:
            cur["items"].append(line)
    return out


def linkify(line):
    """Escape a line, turning bare https:// URLs into anchors."""
    out, rest = [], esc(line)
    while "https://" in rest:
        pre, rest = rest.split("https://", 1)
        url, tail = rest, ""
        for cut in " )<>\"']":
            if cut in rest:
                rest, tail = rest.split(cut, 1)
                url = url[:len(url) - len(tail) - 1]
                break
        out.append(pre)
        out.append('<a href="https://%s" style="color:%s">%s</a>'
                   % (url, C_MOSS, url))
        rest = tail
    return "".join(out) + rest


def dashboard_up(base=None):
    """True when DASHBOARD_HOST:port answers (1s TCP probe). Env seam
    HNGH_DIGEST_DASHBOARD_UP=0/1 for tests/hermetic runs."""
    seam = os.environ.get("HNGH_DIGEST_DASHBOARD_UP")
    if seam is not None:
        return seam == "1"
    base = base or digest_module().dashboard_base_url()
    parts = urlsplit(base)
    try:
        socket.create_connection(
            (parts.hostname, parts.port or 80), timeout=1).close()
        return True
    except OSError:
        return False


def section(title, body_html, note=""):
    """One deck plate + content table. Small-caps plate via
    letter-spacing + uppercase (email clients ignore font-variant)."""
    note_html = (' <span style="color:%s;font-size:10px;letter-spacing:0">'
                 '%s</span>' % (C_ASH, esc(note)) if note else "")
    return (
        '<table role="presentation" width="100%%" cellpadding="0" '
        'cellspacing="0" style="margin-top:14px"><tr><td style='
        '"border-top:2px solid %s;border-bottom:1px solid %s;padding:4px 2px;'
        'font-size:12px;font-weight:700;letter-spacing:.18em;color:%s">'
        '%s%s</td></tr><tr><td style="padding:6px 2px">%s</td></tr></table>'
        % (C_LINE, C_LINE, C_BONE, esc(title), note_html, body_html))


def render_masthead(day, edition):
    return (
        '<table role="presentation" width="100%%" cellpadding="0" '
        'cellspacing="0"><tr><td align="center" style="background:%s;'
        'padding:12px 8px;border-bottom:2px solid %s">'
        '<div style="font-size:18px;font-weight:700;letter-spacing:.14em;'
        'color:%s">THE MACHINE HALL &mdash; MORNING DISPATCH</div>'
        '<div style="font-size:10px;letter-spacing:.08em;color:%s;'
        'margin-top:4px">edition no. %d &middot; %s UTC &middot; '
        'automation/digest/%s.md</div></td></tr></table>'
        % (C_BG, C_LINE, C_BONE, C_ASH, edition, esc(day), esc(day)))


def _stat(label, value, sub="", spark=""):
    """One ledger cell: small-caps label, big number, sparkline strip."""
    return (
        '<td width="25%%" align="center" style="background:%s;border:'
        '1px solid %s;padding:8px 4px">'
        '<div style="font-size:9px;letter-spacing:.12em;color:%s">%s</div>'
        '<div style="font-size:16px;font-weight:700;color:%s">%s</div>'
        '<div style="font-size:10px;color:%s">%s</div>'
        '<div style="font-family:monospace;font-size:11px;color:%s;'
        'letter-spacing:1px">%s</div></td>'
        % (C_PANEL, C_LINE, C_ASH, esc(label), C_BONE, esc(value),
           C_ASH, esc(sub), C_MOSS, esc(spark)))


def render_ledger(spend_t, hourly):
    """THE LEDGER: spend/calls/tokens as a stat band + unicode block
    trend strips (one glyph per hourly bucket)."""
    spend = sum(v for _h, v, _n, _c in hourly)
    calls = sum(n for _h, _v, _t, n in hourly)
    tokens = sum(t for _h, _v, t, _c in hourly)
    spend_h = [(h, v, n) for h, v, n, _c in hourly]
    tok_h = [(h, t, n) for h, _v, t, n in hourly]
    if hourly:
        rows = [('<tr>%s%s%s</tr>') % (
            _stat("METERED SPEND", "$%.2f" % spend,
                  "%d calls / 24h" % calls,
                  sparkline_blocks(spend_h)),
            _stat("TOKENS IN", "{:,.0f}".format(tokens),
                  "24h volume",
                  sparkline_blocks(tok_h)),
            _stat("API CALLS", "%d" % calls, "24h volume", ""))]
    else:
        rows = [('<tr>%s%s</tr>') % (
            _stat("METERED SPEND", "$%s" % (spend_t or "unknown"),
                  "no hourly data", ""),
            _stat("API CALLS", "-", "", ""))]
    return ('<table role="presentation" width="100%%" cellpadding="0" '
            'cellspacing="0">%s</table>' % "".join(rows))


def render_news(digest_text):
    """NEWS FROM THE OUTSIDE WORLD: compact per-item list with source
    attribution, items keep their links."""
    secs = news_sections(digest_text)
    if not secs:
        return section("NEWS FROM THE OUTSIDE WORLD",
                       _quiet("no dispatch blocks today"))
    rows = []
    for s in secs:
        for it in s["items"]:
            color = C_BONE
            if it.startswith("CRITICAL: "):
                color = C_WARN
            rows.append(
                '<tr><td style="padding:3px 2px;border-bottom:1px dotted %s;'
                'font-size:12px;color:%s">%s<span style="color:%s;'
                'font-style:italic;font-size:10px"> &mdash; %s UTC'
                '%s</span></td></tr>'
                % (C_LINE, color, linkify(it), C_ASH, esc(s["time"]),
                   (", sources: " + esc(s["sources"])) if s["sources"] else ""))
    return section(
        "NEWS FROM THE OUTSIDE WORLD",
        '<table role="presentation" width="100%%" cellpadding="0" '
        'cellspacing="0">%s</table>' % "".join(rows),
        "%d dispatch block(s)" % len(secs))


def _quiet(text):
    return '<div style="color:%s;font-size:11px">%s</div>' % (C_ASH, esc(text))


MEGA_RE = re.compile(r"^### NEWS FROM THE MEGASTRUCTURE")


def render_mega(digest_text, base):
    """NEWS FROM THE MEGASTRUCTURE: sessions/plans/research posture rows;
    plan-like rows link the dashboard when it answers."""
    mod = digest_module()
    lines, active = [], False
    for line in digest_text.splitlines():
        if MEGA_RE.match(line):
            active = True
            continue
        if active and line.startswith("## "):
            active = False
        if active and line.strip():
            lines.append(line)
    if not lines:
        lines = [l for l in mod.queue_progress()[0].splitlines()]
    linked = dashboard_up(base)
    rows = []
    for line in lines:
        m = mod.PLAN_ROW.match(line)
        if m and linked:
            body = ('<a href="%s/" style="color:%s">%s</a>%s'
                    % (esc(base), C_MOSS, esc(m.group(1)), esc(line.strip()[len(m.group(1)):])))
        else:
            body = linkify(line)
        rows.append('<tr><td style="padding:2px;font-family:monospace;'
                    'font-size:11px;color:%s">%s</td></tr>' % (C_BONE, body))
    return section(
        "NEWS FROM THE MEGASTRUCTURE",
        '<table role="presentation" width="100%%" cellpadding="0" '
        'cellspacing="0">%s</table>' % "".join(rows))


def render_plain_section(title, lines, mono=False):
    """Generic body for operator items / research / commits / alerts /
    budget: the digest's own lines, one row each (evidence-first — no
    rewrite, no voice drift)."""
    if isinstance(lines, str):
        lines = lines.splitlines()
    style = "font-family:monospace;font-size:11px" if mono \
        else "font-size:12px"
    rows = "".join(
        '<tr><td style="padding:2px;color:%s;%s">%s</td></tr>'
        % (C_BONE, style, linkify(l) if l.strip() else "&nbsp;")
        for l in lines)
    return section(title, '<table role="presentation" width="100%%" '
                   'cellpadding="0" cellspacing="0">%s</table>' % rows)


def digest_text(day):
    """Today's daily digest body (automation/digest/<date>.md), '' when
    absent — the Outside World / Megastructure decks read it verbatim."""
    try:
        with open(os.path.join(AUTOMATION, "digest", "%s.md" % day),
                  encoding="utf-8") as fh:
            return fh.read()
    except OSError:
        return ""


def _edition_number(day):
    """1 + count of daily digest files strictly before <day> — the
    newspaper 'edition no.' (data-derived, not a counter file)."""
    try:
        names = os.listdir(os.path.join(AUTOMATION, "digest"))
    except OSError:
        return 1
    return 1 + sum(1 for n in names
                   if re.fullmatch(r"\d{4}-\d{2}-\d{2}\.md", n) and n < day)



def render_html(g=None):
    """Full email HTML alternative part. g = email_digest.gather() when
    the caller wants one shared pull; otherwise gathered here."""
    mod = digest_module()
    g = g or mod.gather()
    day = g["day"]
    base = mod.dashboard_base_url()
    edition = _edition_number(day)
    hourly = hourly_buckets(day)
    spend_t = g["spend_t"]
    # Layout: body > centering div > 640px container table > sections.
    # Section bodies may hold one nested content table each — max depth
    # 3 (asserted by test_html_table_nesting_depth_bounded).
    parts = ['<!doctype html><html><head><meta charset="utf-8">'
             '<meta name="viewport" content="width=device-width">'
             "<title>hngh daily digest</title></head>"
             '<body style="margin:0;background:%s;color:%s;'
             'font-family:-apple-system,Segoe UI,Helvetica,Arial,sans-serif">'
             '<div align="center" style="padding:10px">'
             '<table role="presentation" width="640" cellpadding="0" '
             'cellspacing="0" style="background:%s"><tr><td>'
             % (C_BG, C_INK, C_BG)]
    body = [render_masthead(day, edition)]
    body.append(section("THE LEDGER",
                        render_ledger(spend_t, hourly),
                        "24h metered spend" if hourly else ""))
    delta = delta_line(mod.compose(g))
    if delta:
        body.append('<div style="color:%s;font-size:11px;padding:2px">'
                    "%s</div>" % (C_ASH, esc(delta)))
    body.append(render_plain_section("OPERATOR ITEMS AWAITING YOU",
                                     mod.operator_items()))
    body.append(render_news(digest_text(day)))
    body.append(render_mega(digest_text(day), base))
    body.append(render_plain_section("LESSONS OF THE DAY", g["lessons"]))
    body.append(render_plain_section("COMMITS (24h)",
                                     [mod.ellipsize(l)
                                      for l in (g["klines"][:5]
                                                + g["alines"][:5])], mono=True))
    body.append(render_plain_section("ALERTS (last 24h)",
                                     g["alerts24"] or ["none — quiet window"]))
    body.append(render_plain_section("BUDGET (telemetry)", mod.budget_lines()))
    body.append(mod.feedback_form_html())
    body.append('<div style="color:%s;font-size:10px;padding:6px 2px">'
                "full digest: logs/email-digest-%s.md | dashboard: %s</div>"
                % (C_ASH, esc(day), esc(base)))
    return ("".join(parts) + "".join(body)
            + "</td></tr></table></div></body></html>")


if __name__ == "__main__":
    sys.stdout.write(render_html())
