#!/usr/bin/env python3
"""hngh-home catalog idempotency (2026-09-13): catalog() called twice
with the same kind+path appends exactly one row; different kind or path
still appends. Hermetic via HNGH_HOME_DIR."""

import os
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "lib"))
import hngh_home  # noqa: E402


class CatalogIdempotency(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        os.environ["HNGH_HOME_DIR"] = self._td.name

    def tearDown(self):
        del os.environ["HNGH_HOME_DIR"]
        self._td.cleanup()

    def rows(self):
        p = Path(self._td.name) / "catalog.tsv"
        return p.read_text().splitlines() if p.exists() else []

    def test_same_kind_path_twice_is_one_row(self):
        hngh_home.catalog("dispatch-edition", "/tmp/x/2026-09-11.md", "n1")
        hngh_home.catalog("dispatch-edition", "/tmp/x/2026-09-11.md", "n2")
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        self.assertIn("dispatch-edition\t/tmp/x/2026-09-11.md", rows[0])

    def test_different_kind_or_path_still_appends(self):
        hngh_home.catalog("dispatch-edition", "/tmp/x/ed.md")
        hngh_home.catalog("digest", "/tmp/x/ed.md")
        hngh_home.catalog("dispatch-edition", "/tmp/x/other.md")
        self.assertEqual(len(self.rows()), 3)

    def test_missing_home_dir_does_not_crash(self):
        self.assertEqual(
            hngh_home.catalog("digest", "/tmp/fresh.md") != "", True)
        self.assertEqual(len(self.rows()), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
