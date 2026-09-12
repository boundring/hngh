#!/usr/bin/env python3
"""digest-html — newspaper-style HTML rendering of one daily digest.

Reads automation/digest/<date>.md verbatim (never rewrites the digest
pipeline), parses its "## HHMM" news blocks (DECK A: NEWS FROM THE
OUTSIDE WORLD) and "### NEWS FROM THE MEGASTRUCTURE" grounded blocks
(DECK B), and renders a self-contained page: masthead, THE LEDGER stat
band with inline-SVG sparklines (telemetry.db, 24h hourly buckets), both
decks, and RESEARCH-BEAT side-notes. Newspaper layout (operator feedback
2026-09-12): monument-plate deck headers, two-column broadsheet decks
with hairline rules, per-story summaries, the day's manga panel as the
comic strip and an ASCII machine-hall text-graphic, one dry evidence-first
quip per section (lib/quips.py, machine metrics only). Images are served
by the jailed /hngh-docs/media/ route (dashboard-server.py); the page
references them by that LAN path and renders fine without them (alt
text). No JS; palette is the display-register tokens from
dashboard/style.css. ASCII output.

usage (module): render_page(digest_path, digests_dir) -> str
"""
import html
import glob as _glob
import importlib.machinery
import importlib.util
import json
import os
import re
import sqlite3

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(ROOT)
TELEMETRY = os.path.join(ROOT, "dashboard", "telemetry.db")
DIGESTS = os.path.join(ROOT, "digest")
MEDIA = os.path.join(REPO, "docs", "media")
SECTION_BUDGET = int(os.environ.get("DIGEST_SECTION_BUDGET", "1200"))
BEAT_SENTENCES = 3
BEAT_RE = re.compile(r"^RESEARCH-BEAT-(\d{4}-\d{2}-\d{2})-.*\.md$")
DATE_FILE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}\.md$")
SECTION_RE = re.compile(r"^## (\d{4}) (\d{4}-\d{2}-\d{2})\s*$")
MEGA_RE = re.compile(r"^### NEWS FROM THE MEGASTRUCTURE")
TOKENS_RE = re.compile(r"tokens in ([0-9][0-9,]*)")


def esc(text):
    """HTML-escape and force ASCII output (non-ASCII -> numeric entities)."""
    return html.escape(str(text), quote=True).encode(
        "ascii", "xmlcharrefreplace").decode("ascii")


def _load_quips():
    """Load lib/quips.py (dash-free name, but keep the explicit loader
    so the renderer runs standalone from any cwd)."""
    loader = importlib.machinery.SourceFileLoader(
        "hngh_quips", os.path.join(ROOT, "lib", "quips.py"))
    spec = importlib.util.spec_from_loader("hngh_quips", loader)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


quips = _load_quips()


def latest_media(pattern):
    """Newest repo media file matching <MEDIA>/<pattern>, or None.
    Display-only: the renderer references the LAN jail path; a missing
    file means no art, never a dead link."""
    hits = sorted(_glob.glob(os.path.join(MEDIA, pattern)))
    return os.path.basename(hits[-1]) if hits else None


def split_headline(body):
    """Deterministic story split: first sentence (never inside a URL)
    is the headline, the remainder is the summary. No fabrication."""
    i = 0
    while True:
        j = body.find(". ", i)
        if j < 0:
            return body, ""
        if "://" in body[i:j + 1]:
            i = j + 1
            continue
        return body[:j + 1], body[j + 2:].strip()


def machine_hall(hourly):
    """The machine hall as an ASCII text-graphic: 24 hourly spend
    columns, bone-on-void. Deterministic; '#' heavy, ':' light."""
    peak = max([h[1] for h in hourly] or [0]) or 1.0
    heights = [max(0, min(6, round(6 * h[1] / peak))) for h in hourly]
    rows = []
    for level in (5, 3, 1):
        rows.append("".join("#" if h >= level + 1 else
                            (":" if h >= max(1, level) else ".") if h else " "
                            for h in heights))
    rows.append("".join("^" if h[3] else " " for h in hourly))
    rows.append("00-------06-------12-------18-------23  UTC")
    return "\n".join(rows)


def comic_html(date):
    """The paper's comic strip: the newest manga panel, or nothing."""
    name = latest_media(os.path.join("manga", "*.png"))
    if not name:
        return []
    src = "/hngh-docs/media/manga/%s" % name
    caption = quips.quip("comic", date) or ""
    return ['<figure class="comic"><img src="%s" alt="the day\'s manga '
            'panel: %s"><figcaption>%s</figcaption></figure>'
            % (esc(src), esc(name), esc(caption))]


def digest_index(digests_dir=DIGESTS):
    """Daily digests, newest mtime first: [{name, date, mtime, size}]."""
    rows = []
    try:
        for name in sorted(os.listdir(digests_dir)):
            if not DATE_FILE_RE.fullmatch(name):
                continue
            path = os.path.join(digests_dir, name)
            if os.path.isfile(path):
                rows.append({"name": name, "date": name[:-3],
                             "mtime": int(os.path.getmtime(path)),
                             "size": os.path.getsize(path)})
    except OSError:
        pass
    rows.sort(key=lambda r: r["mtime"], reverse=True)
    return rows


def parse_sections(text):
    """Split digest text into news blocks: [{time, date, sources, model,
    items, mega}] preserving order. Prose is kept verbatim."""
    sections = []
    cur = None
    for line in text.splitlines():
        m = SECTION_RE.match(line)
        if m:
            cur = {"time": m.group(1), "date": m.group(2),
                   "sources": "", "model": "", "items": [], "mega": False}
            sections.append(cur)
            continue
        if MEGA_RE.match(line):
            cur = {"time": "", "date": "", "sources": "", "model": "",
                   "items": [], "mega": True}
            sections.append(cur)
            continue
        if cur is None or not line.strip():
            continue
        if line.startswith("_sources: ") and line.endswith("_"):
            body = line[len("_sources: "):-1]
            if " | model: " in body:
                src, model = body.split(" | model: ", 1)
                cur["sources"], cur["model"] = src.strip(), model.strip(" _")
            else:
                cur["sources"] = body.strip()
        elif line.startswith("<!--") or line.startswith("###"):
            continue
        else:
            cur["items"].append(line)
    return sections


def telemetry_hourly(date, db=TELEMETRY):
    """24 hourly buckets for <date>: (hour, cost_usd, tokens_in, calls)."""
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


def beats_timeline(date, db=TELEMETRY):
    """Research-beat event times for <date>, hour-fraction 0..1 each."""
    if not os.path.isfile(db):
        return []
    try:
        conn = sqlite3.connect("file:%s?mode=ro" % db, uri=True, timeout=5)
        rows = conn.execute(
            "SELECT substr(ts,12,2), substr(ts,15,2) FROM events"
            " WHERE kind='research' AND ts LIKE ? || 'T%'"
            " ORDER BY ts", (date,)).fetchall()
        conn.close()
    except Exception:
        return []
    return [(int(h) * 60 + int(m)) / 1440.0 for h, m in rows]


def sparkline(values, width=560, height=36):
    """Inline SVG polyline; zero-only data renders an honest flat base."""
    vals = [v for _, v, _, _ in values] if values and len(values[0]) == 4 \
        else list(values)
    peak = max(vals) if vals else 0
    pts = []
    for i, v in enumerate(vals):
        x = i * width / max(len(vals) - 1, 1)
        y = height - 2 - (v / peak) * (height - 6) if peak > 0 else height - 2
        pts.append("%.1f,%.1f" % (x, y))
    return ("<svg class=\"spark\" viewBox=\"0 0 %d %d\" preserveAspectRatio"
            "=\"none\" role=\"img\"><polyline fill=\"none\" points=\"%s\"/>"
            "</svg>" % (width, height, " ".join(pts)))


def beat_sidenotes(date, digests_dir=DIGESTS):
    """First BEAT_SENTENCES of each RESEARCH-BEAT-<date>-*.md, with the
    jail-served raw-md link (/digest/<name>.md)."""
    notes = []
    try:
        names = sorted(n for n in os.listdir(digests_dir)
                       if BEAT_RE.fullmatch(n) and n[14:24] == date)
    except OSError:
        return notes
    for name in names:
        try:
            with open(os.path.join(digests_dir, name),
                      encoding="utf-8") as f:
                text = f.read()
        except OSError:
            continue
        body = re.sub(r"[#=*_`|>-]+", " ", text)
        body = re.sub(r"\s+", " ", body).strip()
        sentences = re.split(r"(?<=\.)\s+", body)
        excerpt = " ".join(sentences[:BEAT_SENTENCES])
        notes.append({"name": name, "excerpt": excerpt[:400]})
    return notes


STYLE = """
:root{--bg:#0d1117;--panel:#161b22;--line:#30363d;--ink:#e6edf3;
--muted:#99a3ae;--accent:#2f81f7;--ok:#3fb950;--warn:#d29922}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
font:11.5px/1.35 -apple-system,'Segoe UI',Helvetica,Arial,sans-serif}
#digest-page{max-width:1180px;margin:0 auto;padding:14px 18px 40px}
.masthead{border-bottom:2px solid var(--line);text-align:center;
padding:10px 0 8px;margin-bottom:12px}
.masthead h1{margin:0;font-size:21px;letter-spacing:.14em;
font-weight:700;font-variant:small-caps}
.masthead .edition{color:var(--muted);font-size:10.5px;letter-spacing:.08em;
margin-top:3px;font-variant:small-caps}
.deck-plate{font-variant:small-caps;letter-spacing:.22em;font-size:13px;
border-top:2px solid var(--line);border-bottom:1px solid var(--line);
padding:6px 2px;margin:36px 0 12px;color:var(--ink)}
.deck-plate small{color:var(--muted);letter-spacing:.06em;
text-transform:none;float:right}
.cols{column-count:2;column-gap:20px;column-rule:1px solid var(--line)}
@media(max-width:1099px){.cols{column-count:1}}
.block{break-inside:avoid;padding:4px 0 8px;border-bottom:1px dotted var(--line)}
.block .stamp{color:var(--muted);font-variant:small-caps;letter-spacing:.1em;
font-size:10.5px}
.block .src{color:var(--muted);font-size:10px;font-style:italic}
.item{margin:3px 0}
.item .hl{font-weight:700}
.item .sum{display:block;color:var(--muted);font-size:10.5px;margin:1px 0 2px}
.item .tag{font-variant:small-caps;letter-spacing:.08em;font-weight:700}
.item.critical .tag{color:var(--warn)}
.item.notable .tag{color:var(--accent)}
.item.context .tag{color:var(--muted)}
.item a{color:var(--accent);text-decoration:none}
.lead{font-size:12.5px}
.lead::first-letter{float:left;font-size:34px;line-height:.9;
padding:2px 5px 0 0;color:var(--ink);font-weight:700}
.editnote{color:var(--muted);font-style:italic;font-size:10.5px}
"""

STYLE += """
.quip{color:var(--muted);font-style:italic;font-size:11px;margin:6px 0 2px}
.quip::before{content:"-- ";color:var(--muted)}
.hero img{width:100%;display:block;border:1px solid var(--line)}
.comic{text-align:center;border:1px solid var(--line);background:var(--panel);
padding:8px;margin:8px 0;break-inside:avoid}
.comic img{max-width:100%;max-height:360px;display:block;margin:0 auto}
.comic figcaption{color:var(--muted);font-size:10px;font-style:italic;
margin-top:4px}
.machinehall{background:var(--panel);border:1px solid var(--line);
color:var(--ink);font:12px/1.2 ui-monospace,Menlo,Consolas,monospace;
padding:8px 10px;letter-spacing:.08em;overflow-x:auto;white-space:pre;
margin:8px 0}
"""

STYLE += """
.ledger{display:grid;grid-template-columns:repeat(4,1fr);gap:8px;
margin:10px 0 4px}
@media(max-width:1099px){.ledger{grid-template-columns:repeat(2,1fr)}}
.stat{background:var(--panel);border:1px solid var(--line);padding:6px 8px}
.stat .k{color:var(--muted);font-variant:small-caps;letter-spacing:.1em;
font-size:10px}
.stat .v{font-size:15px;font-weight:700}
.stat .d{color:var(--muted);font-size:10px}
.spark{width:100%;height:36px}
.spark polyline{stroke:var(--accent);stroke-width:1.4}
.spark.tokens polyline{stroke:var(--ok)}
.ticks{position:relative;height:14px;background:var(--panel);
border:1px solid var(--line);margin-top:4px}
.ticks i{position:absolute;top:1px;bottom:1px;width:2px;background:var(--warn)}
table.beats{width:100%;border-collapse:collapse;font-size:11px}
table.beats th{font-variant:small-caps;letter-spacing:.08em;color:var(--muted);
text-align:left;border-bottom:1px solid var(--line);padding:3px 6px}
table.beats td{border-bottom:1px dotted var(--line);padding:3px 6px;
vertical-align:top}
table.beats td.crit{color:var(--warn)}
.mega ul{margin:4px 0;padding-left:16px}
.mega li{margin:2px 0}
.mega .feedsrc{color:var(--muted);font-size:9.5px;font-style:italic}
.sidenote{background:var(--panel);border:1px solid var(--line);
padding:6px 8px;margin:6px 0;font-size:10.5px;color:var(--muted)}
.sidenote b{color:var(--ink)}
.sidenote a{color:var(--accent);text-decoration:none}
"""


def _linkify(line):
    """Escape a digest line, turning bare URLs into anchors."""
    out, rest = [], esc(line)
    while "https://" in rest:
        pre, rest = rest.split("https://", 1)
        url, tail = rest, ""
        for cut in " )<>\"']":
            if cut in rest:
                rest, tail = rest.split(cut, 1)
                url, tail = url[:len(url) - len(tail) - 1], tail
                break
        out.append(pre)
        out.append('<a href="https://%s">https://%s</a>'
                   % (url, url.replace("&#39;", "")))
        rest = tail
    return "".join(out) + rest


def render_item(line, lead=False, standfirst=""):
    cls = "item"
    if line.startswith("CRITICAL: "):
        cls += " critical"
        tag, body = "CRITICAL", line[len("CRITICAL: "):]
    elif line.startswith("NOTABLE: "):
        cls += " notable"
        tag, body = "NOTABLE", line[len("NOTABLE: "):]
    elif line.startswith("CONTEXT: "):
        cls += " context"
        tag, body = "CONTEXT", line[len("CONTEXT: "):]
    else:
        tag, body = "", line
    head, rest = split_headline(body)
    if not rest:
        rest = standfirst
    sum_el = ""
    if rest:
        sum_el = '<span class="sum">%s</span>' % _linkify(rest)
    return ('<p class="%s%s">%s<span class="hl">%s</span>%s</p>'
            % (cls, " lead" if lead else "",
               '<span class="tag">%s:</span> ' % tag if tag else "",
               _linkify(head), sum_el))


def _deck_a_facts(news):
    items = [it for s in news for it in s["items"]]
    return {
        "blocks": len(news),
        "criticals": sum(1 for it in items if it.startswith("CRITICAL: ")),
        "quiet_wins": sum(1 for it in items if "quiet window" in it),
    }


def render_deck_a(sections, edition_count):
    """News blocks of the day; leads with the most consequential item
    (first CRITICAL on record, else first NOTABLE) — data pick, not taste."""
    news = [s for s in sections if not s["mega"] and s["items"]]
    lead, lead_src = None, None
    for s in news:
        for it in s["items"]:
            if it.startswith("CRITICAL: "):
                lead, lead_src = it, s
                break
        if lead:
            break
    if lead is None and news:
        for s in news:
            for it in s["items"]:
                if it.startswith("NOTABLE: "):
                    lead, lead_src = it, s
                    break
            if lead:
                break
    parts = ['<div class="deck-plate">Deck A &mdash; News from the Outside World'
             '<small>%d hourly dispatch blocks &middot; %s</small></div>'
             % (len(news), esc(news[0]["date"]) if news else "")]
    if lead:
        why = ("Leads the deck: severity CRITICAL on the importance screen "
               if lead.startswith("CRITICAL: ")
               else "Leads the deck: highest severity NOTABLE on the "
                    "importance screen ")
        why += "at %s UTC." % lead_src["time"] if lead_src else "today."
        parts.append('<div class="editnote">%s</div>' % esc(why))
        parts.append(render_item(
            lead, lead=True,
            standfirst="Filed via %s, screened by %s at %s UTC."
            % (lead_src["sources"].split(",")[0] if lead_src["sources"]
               else "the wire",
               lead_src["model"] or "the screen", lead_src["time"])))
    quip = quips.quip("deck_a", news[0]["date"] if news else "",
                      **_deck_a_facts(news))
    if quip and news:
        parts.append('<p class="quip">%s</p>' % esc(quip))
    parts.append('<div class="cols">')
    for s in news:
        chunk = []
        chunk.append('<div class="block"><span class="stamp">%s UTC</span>'
                     '<span class="src"> &middot; sources: %s &middot; %s'
                     '</span>' % (esc(s["time"]), esc(s["sources"]),
                                  esc(s["model"])))
        items = [x for x in s["items"] if x is not lead]
        used = 0
        for it in items:
            if used > SECTION_BUDGET:
                chunk.append('<p class="editnote">[continued in the raw '
                             'digest &mdash; section budget %d chars]</p>'
                             % SECTION_BUDGET)
                break
            used += len(it)
            chunk.append(render_item(
                it, standfirst="Filed via %s, screened by %s at %s UTC."
                % (s["sources"].split(",")[0] if s["sources"] else "the wire",
                   s["model"] or "the screen", s["time"] or "00:00")))
        chunk.append("</div>")
        parts.append("".join(chunk))
    parts.append("</div>")
    return "\n".join(parts)


def render_deck_b(sections, sidenotes, date=""):
    """Grounded megastructure blocks verbatim + research-beat side-notes."""
    megas = [s for s in sections if s["mega"]]
    mega_text = " ".join(it for s in megas for it in s["items"])
    m = TOKENS_RE.search(mega_text)
    quip = (quips.quip("deck_b", date,
                       tokens=int(m.group(1).replace(",", "")))
            if megas and m else None)
    parts = ['<div class="deck-plate">Deck B &mdash; News from the '
             'Megastructure<small>%d grounded blocks</small></div>'
             % len(megas)]
    if quip:
        parts.append('<p class="quip">%s</p>' % esc(quip))
    parts.append('<div class="cols"><div class="mega">')
    for s in megas:
        parts.append("<ul>")
        for it in s["items"]:
            if it.startswith("<!-- feeds: "):
                parts.append('<li class="feedsrc">%s</li>' % esc(it))
            else:
                parts.append("<li>%s</li>" % _linkify(it))
        parts.append("</ul>")
    parts.append("</div></div>")
    table = ['<table class="beats"><tr><th>time</th><th>sources</th>'
             '<th>model</th><th>outcome</th></tr>']
    rows = 0
    for s in (x for x in sections if not x["mega"] and x["items"]):
        lead = s["items"][0] if s["items"] else ""
        crit = " crit" if lead.startswith("CRITICAL: ") else ""
        table.append('<tr><td>%s</td><td>%s</td><td>%s</td>'
                     '<td class="o%s">%s</td></tr>'
                     % (esc(s["time"]), esc(s["sources"][:60]),
                        esc(s["model"]), crit, esc(lead[:90])))
        rows += 1
    if rows:
        table.append("</table>")
        parts.append("".join(table))
    if sidenotes:
        parts.append('<div class="deck-plate">Research side-notes'
                     '<small>%d captures</small></div>' % len(sidenotes))
    for n in sidenotes:
        parts.append('<div class="sidenote"><b>%s</b> &mdash; %s '
                     '<a href="/digest/%s">raw md</a></div>'
                     % (esc(n["name"]), esc(n["excerpt"]), esc(n["name"])))
    return "\n".join(parts)


def render_ledger(date, hourly, ticks, db=TELEMETRY):
    calls = sum(h[3] for h in hourly)
    spend = sum(h[1] for h in hourly)
    tokens = sum(h[2] for h in hourly)
    return "\n".join([
        '<div class="deck-plate">The Ledger<small>24h &middot; %s &middot; '
        'dashboard/telemetry.db</small></div>' % esc(date),
        '<div class="ledger">',
        '<div class="stat"><div class="k">metered spend</div>'
        '<div class="v">$%.2f</div><div class="d">%d calls</div>%s</div>'
        % (spend, calls, sparkline(hourly)),
        '<div class="stat"><div class="k">tokens in</div>'
        '<div class="v">%s</div><div class="d">24h volume</div>%s</div>'
        % ("{:,.0f}".format(tokens),
           sparkline(hourly).replace("spark", "spark tokens")),
        '<div class="stat"><div class="k">beat timeline</div>'
        '<div class="v">%d</div><div class="d">research beats</div>'
        '<div class="ticks">%s</div></div>'
        % (len(ticks), "".join('<i style="left:%.1f%%"></i>'
                               % (t * 100) for t in ticks)),
        '<div class="stat"><div class="k">sources</div>'
        '<div class="v">%d</div><div class="d">dispatch blocks</div>'
        '<div class="d">%s</div></div>'
        % (sum(1 for h in hourly if h[3]),
           "quiet hours: %d" % sum(1 for h in hourly if not h[3])),
        "</div>"])


def hall_html(date, hourly):
    """The machine-hall text-graphic: styled pre + one caption."""
    cap = quips.quip("machine_hall", date) or ""
    return ('<div class="deck-plate">The Machine Hall<small>spend, 24h '
            'text-graphic</small></div>'
            '<pre class="machinehall">%s</pre>'
            '<p class="quip">%s</p>'
            % (esc(machine_hall(hourly)), esc(cap)))


def render_page(digest_path, digests_dir=DIGESTS, db=TELEMETRY):
    """Full self-contained HTML page for one daily digest. Raises on
    unreadable input; the route fail-closes on error."""
    with open(digest_path, encoding="utf-8") as f:
        text = f.read()
    date = os.path.basename(digest_path)[:-3]
    sections = parse_sections(text)
    hourly = telemetry_hourly(date, db)
    ticks = beats_timeline(date, db)
    edition = len(digest_index(digests_dir))
    head = ('<div class="masthead"><h1>The Machine Hall &mdash; Daily '
            'Dispatch</h1><div class="edition">edition no. %d &middot; '
            '%s &middot; automation/digest/%s.md &middot; two decks: '
            'the outside world, the megastructure</div></div>'
            % (edition, esc(date), esc(date)))
    spend = sum(h[1] for h in hourly)
    calls = sum(h[3] for h in hourly)
    quiet = sum(1 for h in hourly if not h[3])
    ledger_quip = quips.quip("ledger", date, spend=spend, calls=calls,
                             quiet=quiet)
    if ledger_quip:
        ledger_quip = '<p class="quip">%s</p>' % esc(ledger_quip)
    hero = latest_media(os.path.join("imagegen", "hero-banner-*.png"))
    hero_html = ('<div class="hero"><img src="/hngh-docs/media/imagegen/%s" '
                 'alt="masthead art: %s"></div>'
                 % (esc(hero), esc(hero))) if hero else ""
    comic = "".join(comic_html(date))
    return ("<!doctype html>\n<html><head><meta charset=\"utf-8\">"
            "<title>Daily Dispatch %s</title><style>%s</style></head>"
            "<body><div id=\"digest-page\">%s%s%s%s%s%s%s%s</div>"
            "</body></html>"
            % (esc(date), STYLE, head, hero_html,
               render_ledger(date, hourly, ticks, db),
               ledger_quip or "",
               render_deck_a(sections, edition), comic,
               hall_html(date, hourly),
               render_deck_b(sections, beat_sidenotes(date, digests_dir),
                             date)))


if __name__ == "__main__":
    import sys
    if len(sys.argv) == 2:
        print(render_page(os.path.join(DIGESTS, sys.argv[1] + ".md")))
