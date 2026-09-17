#!/usr/bin/env python3
"""Identity-seam contract guard: every auto-committer in the automation
writer surfaces pins the machine identity per invocation.

The 2026-09-13 Fixture leak (docs/records/2026-09-16-identity-seam-
reconciliation.md) showed auto-committers taking author identity from
ambient .git/config: 566 commits in that window carry the anonymous
author, including research-beat, kernel/plan ledger sync, torch refresh,
ceremony candidates, and lesson-harvest ticks. The contract (16dae2eb,
config-backup.sh) is per-invocation pinning (`-c user.name=` /
`-c user.email=`) so attribution never depends on ambient config state.

This guard fails when any `git ... commit` invocation in
automation/{cadence,jobs,lib,scripts} lacks an explicit `user.name=`
pin on its (shell-continuation-joined) command line. Hermetic: no git,
no network -- source inspection only. Shell comments are exempt; a
positive control pins config-backup.sh's own seam so the contract
cannot rot silently.
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SURFACES = ("cadence", "jobs", "lib", "scripts")

# `git ... commit` as the git subcommand (not prose like `{commit}` revs).
GIT_COMMIT_RE = re.compile(r"\bgit\b[^\n]*?\scommit\b")
PIN_RE = re.compile(r"user\.name=")


def continuation_joined(text):
    """Join shell line continuations so wrapped commands scan as one."""
    return text.replace("\\\n", " ")


def strip_quoted(line):
    """Drop double-quoted substrings so prose like "git commit failed"
    inside breadcrumb messages cannot masquerade as an invocation."""
    return re.sub(r'"[^"]*"', "", line)


def scan_file(path):
    hits = []
    text = continuation_joined(path.read_text())
    for no, line in enumerate(text.splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("#"):
            continue  # shell comment, not an invocation
        code = strip_quoted(line)
        if GIT_COMMIT_RE.search(code) and not PIN_RE.search(code):
            hits.append((no, stripped))
    return hits


def main():
    violations = []
    for surface in SURFACES:
        base = ROOT / surface
        for path in sorted(base.rglob("*")):
            if not path.is_file():
                continue
            if path.suffix not in (".sh", ".py"):
                continue
            if path.parent.name == "tests":
                continue  # test fixtures legitimately use throwaway identities
            for no, line in scan_file(path):
                violations.append(
                    "%s/%s:%d: unpinned git commit: %s"
                    % (surface, path.name, no, line[:120])
                )

    # Positive control: the reference seam must still be pinned.
    reference = ROOT / "jobs" / "config-backup.sh"
    if not PIN_RE.search(continuation_joined(reference.read_text())):
        violations.append(
            "jobs/config-backup.sh: reference identity seam lost its pin"
        )

    if violations:
        print("identity-seam guard: %d violation(s)" % len(violations))
        for v in violations:
            print("  " + v)
        return 1
    print("identity-seam guard: every automation auto-committer pins "
          "user.name per invocation")
    return 0


if __name__ == "__main__":
    sys.exit(main())
