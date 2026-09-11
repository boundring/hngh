#!/usr/bin/env python3
"""Doc-hygiene guard: no injected tool-call junk in docs/**.md.

Standing gate born from the 2026-09-11 cistern-test-coverage incident:
research docs were written mid-stream by a research beat and captured
raw model tool-call syntax (blockquote tool-call fragments) instead of
prose. Scans every docs/**/*.md file for the junk signature and fails
naming file:line.
"""

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"

# Junk signature lives in lib/docfilter.py -- the single source of
# truth shared with the research beat's capture-side filter
# (corpus-loss cure, 2026-09-11).
sys.path.insert(0, str(ROOT / "lib"))
from docfilter import JUNK_RE


def scan_text(text):
    """Yield (line_number, kind) hits."""
    for n, line in enumerate(text.splitlines(), 1):
        if JUNK_RE.match(line):
            yield n, "tool-call-fragment"


class SelfTest(unittest.TestCase):
    def test_junk_lines_are_caught(self):
        blob = (
            "clean prose\n"
            "<tool_call>\n"
            "<function=Bash>\n"
            "<parameter=command>\n"
            "ls -la\n"
            "</parameter>\n"
            "</function>\n"
            "</tool_call>\n"
        )
        self.assertEqual(
            list(scan_text(blob)),
            [(2, "tool-call-fragment"), (3, "tool-call-fragment"),
             (4, "tool-call-fragment"), (6, "tool-call-fragment"),
             (7, "tool-call-fragment"), (8, "tool-call-fragment")])

    def test_plain_prose_is_allowed(self):
        self.assertEqual(list(scan_text(
            "# Question?\n\nStatus: crystallized.\n")), [])


class RepoScan(unittest.TestCase):
    def test_no_tool_call_junk_in_docs(self):
        bad = []
        for path in sorted(DOCS.rglob("*.md")):
            for n, kind in scan_text(path.read_text(errors="replace")):
                bad.append("%s:%d (%s)" % (
                    path.relative_to(ROOT), n, kind))
        self.assertEqual(bad, [], "tool-call junk found in docs:\n" + "\n".join(bad))


if __name__ == "__main__":
    unittest.main(verbosity=2)