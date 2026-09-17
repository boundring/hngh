#!/usr/bin/env python3
"""research-harvest.py -- the research harvest organ (2026-09-15).

Closes the research lifecycle's missing step (audit:
.agent-scratch/consider/research-lifecycle.md -- 0 of N adopted
dispositions fed anything): when a research disposition lands
action=adopted, condense its verdict into ONE actionable lesson row in
research-lessons.tsv, keyed by line_id -- a re-disposition REFRESHES
the row (new date + lesson) instead of duplicating it, and a later
non-adopted disposition retires the row's status (the knowledge record
never outlives its verdict).

When the llm-wiki project vault is present, the lesson is also appended
as wiki/sources/LES-<line_id>.md in the vault's established page shape
(frontmatter: title, type: source, source_id, captured, file_path,
tags -- same keys as every SRC-* source page; hngh-lessons-current.md
proves hngh-written wiki/ pages are indexed by the extension's
wiki_rebuild_meta rebuild). Hngh NEVER writes meta/ or raw/ (vault
ownership rules, WIKI_SCHEMA.md): the rebuild seam owns indexing, and
the wiki-health probe's UNINDEXED alert covers the gap honestly until
then. Absent/unshaped vault: the TSV alone lands, the wiki append is
skipped.

Fail-closed: a malformed dispositions header or short row exits
non-zero having written nothing (the caller's beat reports it; unknown
input never silently becomes knowledge). Idempotent: an unchanged
adopted disposition re-harvests to a no-op.

usage: research-harvest.py --dispositions TSV --lines TSV --lessons TSV
       [--vault DIR] [--now ISOZ]   (lib use: harvest(...))
"""
import importlib.machinery
import importlib.util
import os
import re
import sys
import time

DISP_SCHEMA = ["line", "action", "verdict", "reviewer", "evidence",
               "date", "support", "oppose", "followons"]
LESS_SCHEMA = ["lesson_id", "date", "line_id", "subject", "lesson",
               "status"]
LESSON_CAP = 240  # one actionable sentence; the verdict is prose


def _load_redact_home():
    """Load the sibling lib/scrub.py (THE single-source redaction
    identity, 2026-09-17 GAP-B cure) without sys.path games: this
    module is executed both as a script by 33-research-beat.sh and
    hermetically via importlib by its test. Fail-closed: a missing or
    broken scrub module raises here -- the beat reports the harvest
    failure and no unguarded lesson row is ever written."""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                        "scrub.py")
    loader = importlib.machinery.SourceFileLoader("hngh_scrub_harvest",
                                                  path)
    spec = importlib.util.spec_from_loader("hngh_scrub_harvest", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod.redact_home


REDACT_HOME = _load_redact_home()


def _clean(text):
    """One printable single-spaced line, capped (model output is data)."""
    line = re.sub(r"\s+", " ", str(text or ""))
    line = "".join(c for c in line if c.isprintable())
    return line.strip()[:LESSON_CAP]


def _lesson_sentence(verdict, doc_path, subject):
    """One actionable sentence from the verdict reason; doc heading or
    subject as fallback when the verdict carries no reason. Every
    source passes redact_home BEFORE cleaning (2026-09-17 GAP-B cure:
    machine-local tokens ride in verdict/evidence/subject text; the
    tilde family is the established lesson convention)."""
    reason = _clean(REDACT_HOME(verdict))
    reason = re.sub(r"^adopted\b[\s\-–—:]*", "", reason,
                    flags=re.IGNORECASE).strip()
    if reason:
        return reason
    try:
        with open(doc_path, encoding="utf-8", errors="replace") as f:
            for ln in f:
                ln = ln.strip()
                if ln.startswith("# ") and len(ln) > 2:
                    return _clean(REDACT_HOME(ln[2:]))
    except OSError:
        pass
    return _clean(REDACT_HOME(subject))


def _load_rows(path, schema):
    """TSV rows as dicts. The dispositions file carries legacy-width
    rows (the writer widened 6->9 columns in place on 2026-09-12 and
    the header upgrade never rewrote old rows): a row NARROWER than
    the schema is a legacy ancestor, padded with empty fields -- but
    only when its prefix parses (>=3 fields: line, action, verdict).
    A row missing the core prefix, or WIDER than the schema (unknown
    trailing fields), fails closed: SystemExit, nothing written."""
    try:
        with open(path, encoding="utf-8") as f:
            raw = f.read().splitlines()
    except FileNotFoundError:
        return []
    if not raw:
        return []
    header = raw[0].split("\t")
    if header != schema:
        sys.stderr.write(
            "research-harvest: %s header drift: %r != %r\n"
            % (path, header, schema))
        raise SystemExit(1)
    rows = []
    for ln in raw[1:]:
        if not ln.strip():
            continue
        fields = ln.split("\t")
        if len(fields) > len(schema) or len(fields) < 3:
            sys.stderr.write(
                "research-harvest: %s malformed row (%d fields): %r\n"
                % (path, len(fields), ln[:120]))
            raise SystemExit(1)
        fields += [""] * (len(schema) - len(fields))
        rows.append(dict(zip(schema, fields)))
    return rows


def _subjects(lines_path):
    """line_id -> subject (lines.tsv col 4); malformed rows skipped
    (enrichment input: a missing subject falls back to the line id)."""
    out = {}
    try:
        with open(lines_path, encoding="utf-8") as f:
            for ln in f.read().splitlines():
                fields = ln.split("\t")
                if len(fields) == 4 and fields[0]:
                    out.setdefault(fields[0], _clean(fields[3]))
    except OSError:
        pass
    return out


def _latest(rows):
    """line_id -> newest disposition row per line (scan order wins:
    the beat appends chronologically) plus that row's action."""
    last, actions = {}, {}
    for r in rows:
        lid = r["line"]
        last[lid] = r
        actions[lid] = r["action"]
    return last, actions


def harvest(dispositions_path, lines_path, lessons_path, vault,
            now=None):
    """Upsert one lesson per adopted line; returns changed-row count."""
    if now is None:
        now = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    rows = _load_rows(dispositions_path, DISP_SCHEMA)
    subjects = _subjects(lines_path)
    latest, actions = _latest(rows)

    try:
        with open(lessons_path, encoding="utf-8") as f:
            raw = f.read().splitlines()
    except FileNotFoundError:
        raw = []
    lessons = {}
    if raw:
        if raw[0].split("\t") != LESS_SCHEMA:
            sys.stderr.write("research-harvest: %s header drift\n"
                             % lessons_path)
            raise SystemExit(1)
        for ln in raw[1:]:
            if not ln.strip():
                continue
            f2 = ln.split("\t")
            if len(f2) != len(LESS_SCHEMA):
                sys.stderr.write(
                    "research-harvest: %s malformed lesson row: %r\n"
                    % (lessons_path, ln[:120]))
                raise SystemExit(1)
            lessons[f2[2]] = f2  # keyed by line_id

    day = now[:10]
    stamp = day.replace("-", "")
    changed = []
    for lid in sorted(latest):
        row = latest[lid]
        subject = subjects.get(lid) or lid
        adopted = actions[lid] == "adopted"
        prev = lessons.get(lid)
        if adopted:
            lesson = _lesson_sentence(row["verdict"], row["evidence"],
                                      subject)
            if prev and prev[4] == lesson and prev[5] == "active":
                continue  # idempotent: unchanged content, no rewrite
            lessons[lid] = ["les-%s-%s" % (stamp, lid), now, lid,
                            REDACT_HOME(subject), lesson, "active"]
            changed.append(lid)
        elif prev and prev[5] == "active":
            # a later non-adopted disposition retires the lesson
            prev[5] = "retired"
            changed.append(lid)

    if changed:
        tmp = lessons_path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            f.write("\t".join(LESS_SCHEMA) + "\n")
            for lid in sorted(lessons):
                f.write("\t".join(lessons[lid]) + "\n")
        os.replace(tmp, lessons_path)
        if vault:
            for lid in changed:
                if lessons[lid][5] != "active":
                    continue  # retired rows leave the page as-is
                _write_wiki_page(vault, lessons[lid], latest[lid])
    return len(changed)


def _write_wiki_page(vault, lesson, disp):
    """Append/refresh the vault page in the established source-page
    shape. Skips silently when the vault is absent (the TSV alone
    lands); NEVER touches meta/ or raw/."""
    wiki = os.path.join(vault, "wiki", "sources")
    if not os.path.isdir(wiki):
        return
    lid = lesson[2]
    page = os.path.join(wiki, "LES-%s.md" % lid)
    title = "Research Lesson: %s" % lesson[3]
    evidence = REDACT_HOME(disp["evidence"])
    text = (
        "---\n"
        "title: \"%s\"\n"
        "type: source\n"
        "source_id: LES-%s\n"
        "captured: %s\n"
        "file_path: \"%s\"\n"
        "tags:\n  - hngh\n  - research\n  - lesson\n"
        "---\n\n"
        "# %s\n\n"
        "## Summary\n"
        "%s\n\n"
        "Adopted research line `%s` (reviewed %s); crystallized evidence "
        "at the file_path above. Harvested by the hngh research beat "
        "into automation/research-lessons.tsv (row `%s`).\n\n"
        "Back to [[index]].\n"
        % (title, lid, lesson[1][:10], evidence, title,
           lesson[4], lid, disp["date"], lesson[0]))
    tmp = page + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, page)


def main(argv):
    args = {"--dispositions": None, "--lines": None, "--lessons": None,
            "--vault": "", "--now": None}
    i = 1
    while i < len(argv):
        key = argv[i]
        if key not in args or i + 1 >= len(argv):
            sys.stderr.write("research-harvest: bad args\n")
            return 2
        args[key] = argv[i + 1]
        i += 2
    for req in ("--dispositions", "--lines", "--lessons"):
        if not args[req]:
            sys.stderr.write("research-harvest: --%s required\n"
                             % req[2:])
            return 2
    n = harvest(args["--dispositions"], args["--lines"],
                args["--lessons"], args["--vault"] or None,
                now=args["--now"])
    print("research-harvest: %d lesson row(s) appended/refreshed" % n)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
