#!/usr/bin/env python3
"""crumbs - the single STATE.md crumb-append entrypoint.

Line format (automation/lib/crumbs-db.py's importer is the format
authority):

    <ISO UTC ts> | <job> | <event> | <detail>       (exactly one line)

Every STATE.md crumb writer routes here - lib/breadcrumbs.sh (shim over
this CLI), scripts/router-tick.py, jobs/feedback-apply.py,
jobs/service-state.py - so the format, timestamp, and append live in
one implementation.

Fail closed: crumb() refuses (ValueError; CLI exit 2) any field
containing the field separator (|) or a newline - the two classes the
importer would silently mis-import (field shift when job/event carry
" | ") or skip (line spill on newline). Callers that accept free text
normalize it first with scrub() (the strictest common detail form the
writers converged on: pipes escaped, whitespace runs folded); the shell
shim keeps its documented bash fold for byte-identical output.

Seam: STATE_FILE env selects the journal (default automation/STATE.md).

usage: lib/crumbs.py JOB EVENT DETAIL
"""
import os
import sys
import time

AUTO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def now_utc():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def scrub(detail):
    """Strictest common detail form: pipes escaped to \\u00a6, one line,
    single spaces (byte-equal to the router-tick/service-state fold)."""
    return " ".join(detail.replace("|", "\u00a6").split())


def crumb(job, event, detail, state_file=None):
    """Append one 4-field crumb line to the journal and return it.
    Raises ValueError when a field contains the separator or a newline."""
    for value in (job, event, detail):
        if "|" in value or "\n" in value or "\r" in value:
            raise ValueError(
                "crumb field contains separator/newline: %r" % (value,))
    path = state_file or os.environ.get("STATE_FILE") \
        or os.path.join(AUTO_ROOT, "STATE.md")
    line = "%s | %s | %s | %s\n" % (now_utc(), job, event, detail)
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "a", encoding="utf-8") as fh:
        fh.write(line)
    return line


if __name__ == "__main__":
    try:
        crumb(sys.argv[1], sys.argv[2], sys.argv[3])
    except (IndexError, ValueError) as exc:
        print("crumbs: %s" % exc, file=sys.stderr)
        raise SystemExit(2)
