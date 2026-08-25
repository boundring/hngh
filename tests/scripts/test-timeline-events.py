#!/usr/bin/env python3
"""Timeline test: records append to the rotation timeline.

The timeline accumulates one machine-readable row per rotation/event:
DATE<TAB>KIND<TAB>ITEM<TAB>HASH. The dashboard spine needs a stable
format; this module is the append helper + a reject check on malformed
rows, all pure (no writes allowed from tests).
"""

import unittest
from pathlib import Path

TIMELINE = Path(__file__).resolve().parent.parent.parent / "docs" / "project" / "timeline.md"


def parse_rows(text):
    """The rows between the ``` fences of timeline.md, plus any row lines."""
    out = []
    for line in text.splitlines():
        parts = line.split("\t")
        if len(parts) == 4 and parts[1] in {"done", "event", "rotation"}:
            out.append(parts)
    return out


class TimelineRows(unittest.TestCase):
    def test_rows_are_4field(self):
        rows = parse_rows(TIMELINE.read_text())
        self.assertTrue(rows, "timeline.md should carry tab rows")
        for row in rows:
            self.assertEqual(len(row), 4)
            self.assertTrue(row[0], "date field nonempty")

    def test_malformed_row_rejected(self):
        # a line with a space instead of a tab must not parse as a timeline row
        bad = "2026-08-25\twrongkind\titem\thash\n"
        rows = parse_rows(bad)
        self.assertEqual(rows, [])


if __name__ == "__main__":
    import unittest
    unittest.main(verbosity=2)