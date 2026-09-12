#!/usr/bin/env python3
"""digest-public — the public newspaper edition of one daily digest.

Same data pulls as jobs/digest-html.py (it reuses that module's parsers
and telemetry readers), but the output is GitHub-safe markdown for
docs/dispatch/<date>.md: masthead, THE LEDGER numbers, Deck A (outside
world, verbatim digest items), Deck B (grounded megastructure blocks),
the day's lessons, and links to the journal. Deterministic, stdlib only,
ASCII output; fails open (returns "" on unreadable feeds) so the daily
writer can never break on it.

usage (module): write_publication(date, repo) -> Path | None
       jobs/digest-public.py <YYYY-MM-DD>   (prints the markdown)
"""
import importlib.machinery
import importlib.util
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
        "## Deck A - News from the Outside World",
        "",
    ]
    for s in news:
        out.append("### %s UTC" % s["time"])
        out.append("")
        out.append("_sources: %s | model: %s_" % (_ascii(s["sources"]),
                                                  _ascii(s["model"])))
        out.append("")
        for it in s["items"]:
            out.append("- %s" % _ascii(it))
        out.append("")
    out += ["## Deck B - News from the Megastructure", ""]
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
