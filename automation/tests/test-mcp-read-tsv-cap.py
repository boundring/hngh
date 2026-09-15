#!/usr/bin/env python3
"""read_tsv ROW_CAP semantics, hermetic.

Contract: research TSVs are oldest-first append order, so when a read is
capped at ROW_CAP the NEWEST (last) rows must be kept, never the oldest.
A 250-row file must yield the last 200 rows, in file order, with
truncated=True.
"""

import importlib.util
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SERVER = ROOT / "mcp" / "hngh_mcp_server.py"

spec = importlib.util.spec_from_file_location("hngh_mcp_server", str(SERVER))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class ReadTsvCap(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name)

    def tearDown(self):
        self._td.cleanup()

    def _write(self, name, header, n):
        path = self.root / name
        lines = [header] if header else []
        for i in range(1, n + 1):
            row = ["row%03d" % i, "open", "2026-09-15", "row %d" % i]
            if header:
                row = ["row%03d" % i, "adopted", "keep", "rev", "/e", "2026-09-%02d" % ((i % 28) + 1)]
            lines.append("\t".join(row))
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return path

    def test_newest_rows_kept_positional(self):
        path = self._write("research-lines.tsv", None, 250)
        rows, truncated = mod.read_tsv(path, None)
        self.assertTrue(truncated)
        self.assertEqual(len(rows), mod.ROW_CAP)
        self.assertEqual(rows[0]["line"], "row%03d" % (250 - mod.ROW_CAP + 1))
        self.assertEqual(rows[-1]["line"], "row250")

    def test_newest_rows_kept_header(self):
        path = self._write("research-dispositions.tsv", "line\taction\tverdict\treviewer\tevidence\tdate", 250)
        rows, truncated = mod.read_tsv(path, ["line", "action", "verdict", "reviewer", "evidence", "date"])
        self.assertTrue(truncated)
        self.assertEqual(len(rows), mod.ROW_CAP)
        self.assertEqual(rows[0]["line"], "row%03d" % (250 - mod.ROW_CAP + 1))
        self.assertEqual(rows[-1]["line"], "row250")

    def test_under_cap_unchanged(self):
        path = self._write("research-lines.tsv", None, 50)
        rows, truncated = mod.read_tsv(path, None)
        self.assertFalse(truncated)
        self.assertEqual(len(rows), 50)
        self.assertEqual(rows[0]["line"], "row001")


if __name__ == "__main__":
    unittest.main()
