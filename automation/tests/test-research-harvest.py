#!/usr/bin/env python3
"""test-research-harvest.py -- the research harvest organ (hermetic,
2026-09-15). When a research disposition lands action=adopted, the
harvest appends a condensed lesson row to research-lessons.tsv (keyed
by line_id: a re-disposition REFRESHES the row, never duplicates) and,
when a real llm-wiki vault is present, appends the lesson as a
wiki/sources/<id>.md page in the vault's established shape (type:
source frontmatter; the extension's wiki_rebuild_meta indexes it).
Non-adopted dispositions harvest nothing. Malformed input fails closed.
"""
import importlib.util
import os
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

NOW = "2026-09-15T12:00:00Z"


def load(name, rel):
    spec = importlib.util.spec_from_file_location(
        name, os.path.join(ROOT, rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


DISP_SCHEMA = "line\taction\tverdict\treviewer\tevidence\tdate\tsupport\toppose\tfollowons"
LESS_SCHEMA = "lesson_id\tdate\tline_id\tsubject\tlesson\tstatus"


def write(path, text):
    with open(path, "w") as f:
        f.write(text)


def read(path):
    with open(path) as f:
        return f.read()


def main():
    td = tempfile.mkdtemp(prefix="research-harvest-")
    rh = load("research_harvest", "lib/research-harvest.py")

    lines = os.path.join(td, "research-lines.tsv")
    disp = os.path.join(td, "research-dispositions.tsv")
    lessons = os.path.join(td, "research-lessons.tsv")
    vault = os.path.join(td, "vault")
    os.makedirs(os.path.join(vault, "wiki", "sources"))
    write(os.path.join(vault, "WIKI_SCHEMA.md"), "# LLM Wiki Schema\n")

    doc = os.path.join(td, "2026-09-01-line-a.md")
    write(doc, "# Line A findings\n\nBody.\n")

    write(lines, "line-a\treviewed\t2026-09-01T00:00:00Z\tline a subject\n"
                 "line-b\treviewed\t2026-09-02T00:00:00Z\tline b subject\n")
    write(disp, DISP_SCHEMA + "\n"
          + "\t".join(["line-a", "adopted",
                       "adopted -- Ship the slice-first log renderer; validate it under load next.",
                       "model:test", doc, "2026-09-01",
                       "sup", "opp", ""]) + "\n"
          + "\t".join(["line-b", "killed",
                       "killed -- duplicate of line-a; keep record", "model:test",
                       doc, "2026-09-02", "sup", "opp", ""]) + "\n")

    # 1. harvest on adopted: exactly one lesson row, correct shape
    n = rh.harvest(disp, lines, lessons, vault, now=NOW)
    assert n == 1, n
    rows = read(lessons).splitlines()
    assert rows[0] == LESS_SCHEMA, rows[0]
    assert len(rows) == 2, rows
    f = rows[1].split("\t")
    assert f[2] == "line-a", f
    assert f[0] == "les-20260915-line-a", f
    assert f[1] == NOW, f[1]
    assert f[3] == "line a subject", f[3]
    assert f[4] == "Ship the slice-first log renderer; validate it under load next.", f[4]
    assert f[5] == "active", f

    # 2. non-adopted ignored: killed row produced nothing (still 1 row)
    # 3. refresh-not-duplicate: line-a re-adopted later with a new verdict
    with open(disp, "a") as fh:
        fh.write("\t".join(["line-a", "adopted",
                            "adopted -- Refreshed: prefer contract-driven logging in all new UI work.",
                            "model:test", doc, "2026-09-10", "sup", "opp", ""]) + "\n")
        fh.write("\t".join(["line-b", "parked",
                            "parked -- keep the record, no action now", "model:test",
                            doc, "2026-09-10", "sup", "opp", ""]) + "\n")
    n = rh.harvest(disp, lines, lessons, vault, now="2026-09-15T13:00:00Z")
    assert n == 1, n
    rows = read(lessons).splitlines()
    assert len(rows) == 2, rows  # one row per line_id, never duplicated
    f = rows[1].split("\t")
    assert f[0] == "les-20260915-line-a", f  # lesson_id refreshed with the date
    assert f[1] == "2026-09-15T13:00:00Z", f[1]
    assert f[4].startswith("Refreshed:"), f[4]

    # 4. idempotent rerun: no change at all
    before = read(lessons)
    n = rh.harvest(disp, lines, lessons, vault, now="2026-09-15T14:00:00Z")
    assert n == 0, n
    assert read(lessons) == before

    # 5. multiple distinct adopted lines -> one row each
    with open(disp, "a") as fh:
        fh.write("\t".join(["line-b", "adopted",
                            "adopted -- b lesson", "model:test", doc,
                            "2026-09-11", "sup", "opp", ""]) + "\n")
    n = rh.harvest(disp, lines, lessons, vault, now=NOW)
    assert n == 1, n
    assert len(read(lessons).splitlines()) == 3

    # 6. wiki append: exact vault shape, keyed by line_id (refreshed in
    # place, never duplicated)
    page = os.path.join(vault, "wiki", "sources", "LES-line-a.md")
    assert os.path.isfile(page), page
    ptext = read(page)
    assert "type: source" in ptext, ptext
    assert "source_id: LES-line-a" in ptext, ptext
    assert "captured: 2026-09-15" in ptext, ptext
    assert 'file_path: "%s"' % doc in ptext, ptext
    assert "Refreshed:" in ptext, ptext  # refresh updated the page body
    srcdir = os.path.join(vault, "wiki", "sources")
    a_pages = [x for x in os.listdir(srcdir) if x.startswith("LES-line-a")]
    assert a_pages == ["LES-line-a.md"], a_pages

    # 7. absent vault: lessons still land, wiki skipped, rc still success
    # (both lines are adopted by now -> a fresh file gets both rows)
    td2 = tempfile.mkdtemp(prefix="research-harvest-novault-")
    lessons2 = os.path.join(td2, "research-lessons.tsv")
    n = rh.harvest(disp, lines, lessons2, os.path.join(td2, "nope"), now=NOW)
    assert n == 2, n
    rows2 = read(lessons2).splitlines()
    assert len(rows2) == 3, rows2  # header + line-a + line-b
    assert not os.path.exists(os.path.join(td2, "nope"))

    # 8. malformed input fails closed: bad header -> nonzero, no output
    bad = os.path.join(td, "bad-dispositions.tsv")
    write(bad, "wrong\theader\n")
    try:
        rh.harvest(bad, lines, lessons, vault, now=NOW)
        raise AssertionError("malformed header accepted")
    except SystemExit:
        pass
    short = os.path.join(td, "short-row.tsv")
    write(short, DISP_SCHEMA + "\nline-a\tadopted\n")
    try:
        rh.harvest(short, lines, lessons, vault, now=NOW)
        raise AssertionError("short row accepted")
    except SystemExit:
        pass
    wide = os.path.join(td, "wide-row.tsv")
    write(wide, DISP_SCHEMA + "\n" + "\t".join(
        ["line-a", "adopted", "adopted -- x", "m", doc, "2026-09-01",
         "s", "o", "f", "extra-unknown-field"]) + "\n")
    try:
        rh.harvest(wide, lines, lessons, vault, now=NOW)
        raise AssertionError("over-wide row accepted")
    except SystemExit:
        pass

    # 8b. legacy-width rows (pre-2026-09-12 6-column writer schema) are
    # padded, never fatal: the live dispositions file carries them
    legacy = os.path.join(td, "legacy.tsv")
    write(legacy, DISP_SCHEMA + "\n"
          + "\t".join(["line-a", "adopted",
                       "adopted -- legacy verdict sentence", doc,
                       "2026-09-01"]) + "\n"
          + "\t".join(["line-b", "killed", "killed -- dup", doc,
                       "2026-09-02"]) + "\n")
    lessons4 = os.path.join(td, "lessons4.tsv")
    n = rh.harvest(legacy, lines, lessons4, vault, now=NOW)
    assert n == 1, n
    f = read(lessons4).splitlines()[1].split("\t")
    assert f[4] == "legacy verdict sentence", f
    assert f[2] == "line-a", f

    # 9. verdict without a usable reason falls back to the doc/subject
    d2 = os.path.join(td, "disp2.tsv")
    write(d2, DISP_SCHEMA + "\n"
          + "\t".join(["line-a", "adopted", "adopted", "model:test", doc,
                       "2026-09-01", "sup", "opp", ""]) + "\n")
    lessons3 = os.path.join(td, "lessons3.tsv")
    rh.harvest(d2, lines, lessons3, vault, now=NOW)
    f = read(lessons3).splitlines()[1].split("\t")
    assert f[4], f  # non-empty fallback lesson (doc heading or subject)

    print("test-research-harvest: all assertions passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
