#!/usr/bin/env python3
"""digest-public — the public newspaper edition of one daily digest.

Same data pulls as jobs/digest-html.py (it reuses that module's parsers
and telemetry readers), but the output is GitHub-safe markdown for
docs/dispatch/<date>.md: masthead, THE LEDGER numbers, Deck A (outside
world, verbatim digest items), Deck B (grounded megastructure blocks),
the day's lessons, and links to the journal. Newspaper edition (operator
feedback 2026-09-12): per-story summaries, the committed manga panel as
the comic strip (relative link, rendered inline by GitHub), an ASCII
machine-hall text-graphic, and one dry evidence-first quip per section
(the shared quips bank; machine metrics only). Deterministic, stdlib
only, ASCII output; fails open (returns "" on unreadable feeds) so the
daily writer can never break on it.

usage (module): write_publication(date, repo) -> Path | None
       jobs/digest-public.py <YYYY-MM-DD>   (prints the markdown)
"""
import importlib.machinery
import importlib.util
import glob
import re
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_REPO = os.path.dirname(os.path.dirname(HERE))
_DH = None


def _ascii(text):
    return str(text).encode("ascii", "replace").decode("ascii")


def digest_html():
    """Load jobs/digest-html.py once; reuse its section parser and
    telemetry readers so the public edition and the HTML page never
    disagree about the data."""
    global _DH
    if _DH is None:
        loader = importlib.machinery.SourceFileLoader(
            "digest_html", os.path.join(HERE, "digest-html.py"))
        spec = importlib.util.spec_from_loader("digest_html", loader)
        _dh = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_dh)
    return _dh


def lessons_md(day, repo):
    """The day's lessons: the lesson-harvest digest and the ocgo agent
    lessons dated <day>. Fail-open; every line cites its source."""
    out = []
    harvest = os.path.join(repo, "docs", "project",
                           "lessons-%s.md" % day)
    if os.path.isfile(harvest):
        records, drops = 0, 0
        for line in open(harvest, encoding="utf-8"):
            if line.startswith("- 20") and ".md" in line:
                records += 1
            elif line.startswith("- ") and ("rc=" in line or "reason=" in line
                                            or "| session |" in line):
                records += 0
                if "rc=" in line or "reason=" in line:
                    drops += 1
        out.append("<!-- feeds: docs/project/lessons-%s.md -->" % day)
        out.append("- the daily lesson harvest scanned %d new "
                   "lesson-bearing record(s) and %d watchdog "
                   "session-drop(s)." % (records, drops))
    ocgo = os.path.join("automation", "state", "ocgo-agent-lessons.md")
    ocgo = os.path.join(repo, ocgo)
    learned = []
    if os.path.isfile(ocgo):
        try:
            for line in open(ocgo, encoding="utf-8"):
                if line.startswith(day + "T") and "|" in line:
                    learned.append(line.strip())
        except OSError:
            pass
    if learned:
        out.append("<!-- feeds: automation/state/ocgo-agent-lessons.md -->")
        out.append("- %d session lesson(s) filed today; newest cause "
                   "class: %s." % (len(learned),
                                   _ascii(learned[-1].split("|")[1].strip())))
    return out


def comic_md(day, repo):
    """The comic strip: newest committed manga panel as a relative
    image link (GitHub renders committed images), or nothing."""
    hits = sorted(glob.glob(os.path.join(
        repo, "docs", "media", "manga", "*.png")))
    if not hits:
        return []
    name = os.path.basename(hits[-1])
    cap = digest_html().quips.quip("comic", day) or ""
    return ["![the day's manga panel: %s](../media/manga/%s)" % (name, name),
            "", "> %s" % cap, ""]


QUIET_RE = re.compile(r"quiet window")


def hall_md(day, hourly):
    """The machine hall as a fenced ASCII text-graphic with caption."""
    dh = digest_html()
    cap = dh.quips.quip("machine_hall", day) or ""
    return ["## The machine hall (text-graphic)", "", "```",
            dh.machine_hall(hourly), "```", "", "> %s" % cap, ""]


SAGA_CLASSES = {
    "bad-execution": "a creature that knew the shape and stumbled at the gate",
    "missing-knowledge": "a passage the map has never drawn",
    "missing-design": "a question wearing the robes of policy",
    "missing-authority": "a door only the operator's key opens",
    "obsolete": "an old wight rattling past its use",
    "unknown": "a nameless thing moving in the dark",
}
SAGA_MAX_EVENTS = 3


def saga_md(day, repo):
    """The Saga: one short mythic-register line per blocker event and
    one for the night-watch lessons, each footnoted with the ledger row
    it renders. Deterministic templates, no model call; under 8 lines
    a day. The park is the sealed wing; the dream pass is the
    night-watch's preparation."""
    blockers = []
    path = os.path.join(repo, "automation", "state", "beat-blockers.tsv")
    if os.path.isfile(path):
        try:
            for ln in open(path, encoding="utf-8"):
                p = ln.rstrip("\n").split("\t")
                if len(p) >= 6 and p[3].startswith(day):
                    blockers.append(p)
        except OSError:
            pass
    lessons = []
    ocgo = os.path.join(repo, "automation", "state", "ocgo-agent-lessons.md")
    if os.path.isfile(ocgo):
        try:
            for ln in open(ocgo, encoding="utf-8"):
                if ln.startswith(day + "T") and "|" in ln:
                    lessons.append(ln.strip().split("|")[1].strip())
        except OSError:
            pass
    if not blockers and not lessons:
        return []
    out = ["## The Saga", "",
           "*(symbolic register; facts are the cited ledgers.)*", ""]
    for b in blockers[:SAGA_MAX_EVENTS]:
        flavor = SAGA_CLASSES.get(b[2], SAGA_CLASSES["unknown"])
        if b[5] == "parked":
            park = "the park sealed it in a quiet wing"
        else:
            park = "it paces the hall still, watched"
        out.append("In the %s wing the crew met %s: it struck %s "
                   "time(s) on %s, and %s. [^b%s]"
                   % (b[1], flavor, b[4], b[2], park, _ascii(b[0])))
        out.append("[^b%s]: state/beat-blockers.tsv | lane %s | "
                   "cause %s | x%s | %s" % (b[0], b[1], b[2], b[4], b[5]))
    if lessons:
        counts = {}
        for c in lessons:
            counts[c] = counts.get(c, 0) + 1
        out.append("The night-watch filed %d lesson(s) before the "
                   "dawn (%s); the dream pass keeps the watch awake. [^l%s]"
                   % (len(lessons),
                      ", ".join("%s x%d" % (c, n)
                                for c, n in sorted(counts.items())),
                      day))
        out.append("[^l%s]: automation/state/ocgo-agent-lessons.md | "
                   "classes %s." % (day, ", ".join(sorted(counts))))
    return out

def render_page(date, repo):
    """Full markdown edition for <date>. Raises on unreadable digest."""
    dh = digest_html()
    digests = os.path.join(repo, "automation", "digest")
    db = os.path.join(repo, "automation", "dashboard", "telemetry.db")
    with open(os.path.join(digests, date + ".md"), encoding="utf-8") as f:
        sections = dh.parse_sections(f.read())
    hourly = dh.telemetry_hourly(date, db)
    ticks = dh.beats_timeline(date, db)
    edition = len(dh.digest_index(digests))
    calls = sum(h[3] for h in hourly)
    spend = sum(h[1] for h in hourly)
    tokens = sum(h[2] for h in hourly)
    quiet = sum(1 for h in hourly if not h[3])
    news = [s for s in sections if not s["mega"] and s["items"]]
    megas = [s for s in sections if s["mega"]]
    q = dh.quips.quip
    articles = dh.load_articles(
        date, os.path.join(repo, "docs", "articles"))
    items_flat = [it for s in news for it in s["items"]]
    a_facts = {"blocks": len(news),
               "criticals": sum(1 for it in items_flat
                                if it.startswith("CRITICAL: ")),
               "quiet_wins": sum(1 for it in items_flat
                                 if QUIET_RE.search(it))}
    mega_text = " ".join(it for s in megas for it in s["items"])
    m_tokens = dh.TOKENS_RE.search(mega_text)
    out = [
        "# The Machine Hall - Daily Dispatch (public edition)",
        "",
        "Edition no. %d | %s | source: automation/digest/%s.md |"
        " journal: docs/journal/%s.md" % (edition, _ascii(date),
                                          _ascii(date), _ascii(date)),
        "",
        "## THE LEDGER",
        "",
        "<!-- feeds: automation/dashboard/telemetry.db -->",
        "- metered spend: $%.2f across %d model calls (24h)." % (spend, calls),
        "- tokens in: {:,}.".format(tokens),
        "- research beats: %d; dispatch blocks: %d active, %d quiet hours."
        % (len(ticks), len(news), quiet),
        "",
    ]
    ledger_quip = q("ledger", date, spend=spend, calls=calls, quiet=quiet)
    if ledger_quip:
        out += ["> %s" % ledger_quip, ""]
    out += comic_md(date, repo)
    out += hall_md(date, hourly)
    out += [
        "## Deck A - News from the Outside World",
        "",
    ]
    a_quip = q("deck_a", date, **a_facts) if news else None
    if a_quip:
        out += ["> %s" % a_quip, ""]
    for s in news:
        out.append("### %s UTC" % s["time"])
        out.append("")
        out.append("_sources: %s | model: %s_" % (_ascii(s["sources"]),
                                                  _ascii(s["model"])))
        out.append("")
        for it in s["items"]:
            # join by digest-headline (same law as digest-html Deck A)
            tagless = it
            for t in ("CRITICAL: ", "NOTABLE: ", "CONTEXT: "):
                if tagless.startswith(t):
                    tagless = tagless[len(t):]
                    break
            head, _rest = dh.split_headline(tagless)
            art = articles.get(head)
            if QUIET_RE.search(it):
                out.append("- %s" % _ascii(it))
                continue
            head, rest = dh.split_headline(it)
            out.append("- **%s**" % _ascii(head))
            if not rest:
                rest = ("Standfirst: filed via %s, screened by %s at "
                        "%s UTC." % (s["sources"].split(",")[0],
                                     s["model"], s["time"]))
            out.append("  _%s_" % _ascii(rest))
            if art:
                out.append("  _Extended article: "
                           "docs/articles/%s/%s.md_" % (date, art["slug"]))
        out.append("")
    out += ["## Deck B - News from the Megastructure", ""]
    b_quip = (q("deck_b", date,
                tokens=int(m_tokens.group(1).replace(",", "")))
              if megas and m_tokens else None)
    if b_quip:
        out += ["> %s" % b_quip, ""]
    for s in megas:
        for it in s["items"]:
            out.append(_ascii(it))
        out.append("")
    lessons = lessons_md(date, repo)
    if lessons:
        out += ["## Lessons of the day", ""] + lessons + [""]
    saga = saga_md(date, repo)
    out += saga
    if saga:
        out.append("")
    out += [
        "## Reading room",
        "",
        "- The journal (machine ledger + the day's story):"
        " docs/journal/%s.md" % date,
        "- The raw digest: automation/digest/%s.md" % date,
        "- Records and research: docs/records/, docs/research/",
        "",
    ]
    return "\n".join(out)


def write_publication(date, repo=None):
    """Write docs/dispatch/<date>.md; returns the path or None on
    unreadable feeds (fail-open, never breaks the daily writer)."""
    repo = repo or os.environ.get("HNGH_PUB_ROOT") or DEFAULT_REPO
    try:
        text = render_page(date, repo)
    except (OSError, ValueError):
        return None
    target = os.path.join(repo, "docs", "dispatch", date + ".md")
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(target, "w", encoding="utf-8") as f:
        f.write(text)
    return target


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__.strip(), file=sys.stderr)
        sys.exit(2)
    path = write_publication(sys.argv[1])
    if path is None:
        print("digest-public: feeds unreadable; nothing written", file=sys.stderr)
        sys.exit(1)
    print(path)
