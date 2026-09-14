#!/usr/bin/env python3
"""Getting-started link guard: every repo path the page cites must exist.

Scans docs/getting-started.md for markdown link targets and inline
backticked path-like tokens, and fails naming each citation that does
not resolve to a file or directory under the repo root (backticked
tokens are repo-root-relative; markdown links may also resolve
page-relative to docs/). Fenced code blocks are skipped: transcripts
quote absolute paths and full command lines, not repo citations.
Born with the page, peer-hardening plan step 5 (2026-09-10).
"""

import re
import subprocess
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
PAGE = REPO / "docs" / "getting-started.md"


def _gitignored():
    """Paths gitignored somewhere under the repo (host-provisioned set).

    The page documents the operator's live host, where artifacts like
    automation/STATE.md are created at runtime and deliberately never
    committed. A fresh checkout (CI) cannot have them, so a missing
    gitignored path is expected, not a broken citation. Computed once;
    a static allowlist would rot.
    """
    try:
        out = subprocess.run(
            ["git", "ls-files", "--others", "--ignored", "--exclude-standard",
             "--directory", "--no-empty-directory"],
            cwd=REPO, capture_output=True, text=True, timeout=30)
        if out.returncode != 0:
            return frozenset()
        return frozenset(line.rstrip("/") for line in out.stdout.splitlines() if line)
    except Exception:
        return frozenset()


IGNORED = _gitignored()

LINK_RE = re.compile(r"\[[^\]]*\]\(([^)\s]+)\)")
CODE_RE = re.compile(r"`([^`\n]+)`")
PATHISH_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_./-]*$")


def strip_fenced(text):
    """Drop fenced code blocks; inline citations only."""
    kept, fenced = [], False
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            fenced = not fenced
            continue
        if not fenced:
            kept.append(line)
    return "\n".join(kept)


def citations(text):
    """Yield (token, kind) for every repo-path citation in the body."""
    body = strip_fenced(text)
    for m in LINK_RE.finditer(body):
        target = m.group(1)
        if not target.startswith(("http://", "https://", "mailto:", "#")):
            yield target, "link"
    for m in CODE_RE.finditer(body):
        token = m.group(1).strip().rstrip(".,;:)")
        if ("/" in token and not token.startswith(("http://", "https://", "/", "~"))
                and PATHISH_RE.match(token)):
            yield token, "backtick"


def unresolved(text):
    """Return token list failing to resolve under the repo root."""
    seen, bad = set(), []
    for token, kind in citations(text):
        if token in seen:
            continue
        seen.add(token)
        # a gitignored path is host-provisioned (created at runtime on
        # the operator's machine); CI checkouts legitimately lack it
        if token.rstrip("/") in IGNORED:
            continue
        candidates = [REPO / token]
        if kind == "link":
            candidates.append(PAGE.parent / token)
        if not any(c.exists() for c in candidates):
            bad.append(token)
    return bad


class SelfTest(unittest.TestCase):
    def test_missing_path_is_reported(self):
        self.assertEqual(unresolved(
            "run `automation/nope/ghost.sh` then `automation/lib/common.sh`.\n"
        ), ["automation/nope/ghost.sh"])

    def test_non_paths_are_ignored(self):
        self.assertEqual(unresolved(
            "see `http://host:8890/x`, `/tmp/store`, `~/.hngh-automation`, "
            "`make test`, `update_dashboard`, [docs](https://example.com).\n"
        ), [])

    def test_link_resolves_page_relative_and_repo_relative(self):
        self.assertEqual(unresolved(
            "read [root](../README.md) and [records](records/README.md).\n"
        ), [])

    def test_fenced_blocks_are_skipped(self):
        self.assertEqual(unresolved(
            "```text\nautomation/absent/from-transcript.sh\n```\n"
        ), [])


class RepoScan(unittest.TestCase):
    def test_every_cited_path_exists(self):
        self.assertTrue(PAGE.is_file(), "missing page: %s" % PAGE)
        bad = unresolved(PAGE.read_text(errors="replace"))
        self.assertEqual(bad, [], "cited paths missing under %s:\n%s" % (
            REPO, "\n".join(bad)))


if __name__ == "__main__":
    unittest.main(verbosity=2)
