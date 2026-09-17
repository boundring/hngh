#!/usr/bin/env python3
"""Sweep committed research-TSV rows through the redaction family
(2026-09-17 GAP-B follow-through). The writer-seam cures (ingest
2e51d01b, disposition append 6d154d0e, harvest REDACT_HOME) stopped
the flow; this sweep back-redacts the rows that landed raw.

Usage:
  --check        scan the file as it sits now (working tree), report
                 raw-token lines per file, rc=1 when any
  --apply        rewrite via git show HEAD:<path> -> redact_home ->
                 write (then commit); refuses dirty files (rc=2,
                 distinct from rc=1 leaks-found)
  --files a b c  files to process (defaults: the four research TSVs)

Why git-blob-in, file-out: the research beat appends between our read
and write; HEAD blobs are immutable snapshots, and working-tree appends
by the live beat stay untouched. The filter uses lib/scrub.py's
redact_home (the tilde family, one convention across every seam).
"""
import argparse
import importlib.machinery
import importlib.util
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

DEFAULT_FILES = [
    "research-dispositions.tsv",
    "research-lessons.tsv",
    "research-lines.tsv",
    "research-subjects.txt",
]

LOADER = importlib.machinery.SourceFileLoader(
    "hngh_scrub_sweep", os.path.join(ROOT, "lib", "scrub.py"))
SPEC = importlib.util.spec_from_loader("hngh_scrub_sweep", LOADER)
SCRUB = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(SCRUB)
REDACT_HOME = SCRUB.redact_home


def leak_lines(text):
    """Lines that redact_home would still change (raw machine-local
    tokens). The invariant for committed rows is the redact_home
    fixpoint: already-tilde rows and preserved URLs are unchanged by
    the filter, so they are clean by definition."""
    out = []
    for line in str(text or "").splitlines():
        if REDACT_HOME(line) != line:
            out.append(line)
    return out

def head_blob(path):
    """HEAD blob text for path (refuses untracked). Paths are resolved
    against the enclosing git toplevel so a temp-repo fixture (and any
    file outside this repo) resolves inside ITS git, not ours."""
    out = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                         cwd=os.path.dirname(os.path.abspath(path))
                         or ".",
                         capture_output=True, text=True)
    if out.returncode != 0:
        sys.stderr.write("sweep: %s is not inside a git repo\n" % path)
        raise SystemExit(2)
    top = out.stdout.strip()
    rel = os.path.relpath(os.path.abspath(path), top)
    out = subprocess.run(["git", "show", "HEAD:%s" % rel], cwd=top,
                         capture_output=True, text=True)
    if out.returncode != 0:
        sys.stderr.write("sweep: no HEAD blob for %s\n" % path)
        raise SystemExit(2)
    return out.stdout


def worktree_status(path):
    out = subprocess.run(["git", "status", "--porcelain", "--", path],
                         cwd=os.path.dirname(os.path.abspath(path)) or ".",
                         capture_output=True, text=True)
    return out.stdout.strip()


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--apply", action="store_true")
    ap.add_argument("--files", nargs="*", default=DEFAULT_FILES)
    args = ap.parse_args(argv)

    if not args.check and not args.apply:
        ap.error("one of --check / --apply is required")

    failures = []
    refused = False
    for rel in args.files:
        status = worktree_status(rel)
        if args.check:
            try:
                with open(rel, encoding="utf-8") as f:
                    text = f.read()
            except OSError:
                failures.append("%s: unreadable" % rel)
                continue
            leaks = leak_lines(text)
            print("%s: %d raw-token line(s)" % (rel, len(leaks)))
            if leaks:
                failures.append(rel)
            continue
        if status:
            failures.append("%s: dirty in the working tree; HEAD-sweep "
                            "refuses (commit or revert first)" % rel)
            refused = True
            continue
        text = head_blob(rel)
        leaks = leak_lines(text)
        # apply: HEAD blob in, redacted file out; refuse a mid-flight
        # append race by re-checking status right before writing.
        if worktree_status(rel):
            failures.append("%s: went dirty mid-sweep; skipped" % rel)
            continue
        with open(rel, "w", encoding="utf-8") as f:
            f.write(REDACT_HOME(text))
        print("%s: rewrote from HEAD through redact_home "
              "(%d raw line(s) swept)" % (rel, len(leaks)))

    if failures:
        for f in failures:
            sys.stderr.write("sweep: %s\n" % f)
        return 2 if refused else 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
