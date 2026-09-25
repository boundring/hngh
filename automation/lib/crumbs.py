#!/usr/bin/env python3
"""crumbs - the single crumbs-journal write entrypoint.

Line format (automation/lib/crumbs-db.py's importer is the format
authority):

    <ISO UTC ts> | <job> | <event> | <detail>       (exactly one line)

Every crumb writer routes here - lib/breadcrumbs.sh (shim over this
CLI), scripts/router-tick.py, jobs/feedback-apply.py,
jobs/service-state.py - so the format, timestamp, and append live in
one implementation. crumb() writes ONLY state/crumbs.db (the single
write seam); STATE.md is a derived export (lib/crumbs-db.py export).

Fail closed: crumb() refuses (ValueError; CLI exit 2) any field
containing the field separator (|) or a newline - the two classes the
importer would silently mis-import (field shift when job/event carry
" | ") or skip (line spill on newline). Callers that accept free text
normalize it first with scrub() (the strictest common detail form the
writers converged on: pipes escaped, whitespace runs folded); the shell
shim keeps its documented bash fold for byte-identical output.

Seam: HNGH_CRUMBS_DB env or --db selects the journal db (default
automation/state/crumbs.db).

usage: lib/crumbs.py [--db PATH] JOB EVENT DETAIL
"""
import importlib.util
import os
import sys
import time

AUTO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_spec = importlib.util.spec_from_file_location(
    "crumbs_db", os.path.join(AUTO_ROOT, "lib", "crumbs-db.py"))
crumbs_db = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(crumbs_db)


def now_utc():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def scrub(detail):
    """Strictest common detail form: pipes escaped to \\u00a6, one line,
    single spaces (byte-equal to the router-tick/service-state fold)."""
    return " ".join(detail.replace("|", "\u00a6").split())


def crumb(job, event, detail, db_file=None):
    """Append one crumb row to the journal db and return the rendered
    4-field line (with writer stamp). Raises ValueError when a field
    contains the separator or a newline."""
    for value in (job, event, detail):
        if "|" in value or "\n" in value or "\r" in value:
            raise ValueError(
                "crumb field contains separator/newline: %r" % (value,))
    # Writer provenance stamp (fail-20260924-crumbs-mirror-rows R1):
    # process name + rowid (journal coordinate), so a duplicated-row
    # event class stays diagnosable: retry spacing = same content at
    # different rowids, batch-uniform stamps = backfill.
    return crumbs_db.insert_crumb(
        db_file or crumbs_db.db_path(), now_utc(), job, event, detail,
        os.path.basename(sys.argv[0]) or "crumbs")


if __name__ == "__main__":
    argv = sys.argv[1:]
    db = None
    if argv[:1] == ["--db"]:
        db = argv[1]
        argv = argv[2:]
    try:
        crumb(argv[0], argv[1], argv[2], db_file=db)
    except (IndexError, ValueError) as exc:
        print("crumbs: %s" % exc, file=sys.stderr)
        raise SystemExit(2)
