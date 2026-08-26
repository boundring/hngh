#!/usr/bin/env python3
"""Publication smoke: journals, checks, the e-book, and the site.

The generator never touches the repo when tested: module paths are
overridden to temporary directories for the daily/check roundtrip, and
ebook/site write into caller-supplied dirs. --daily refuses to
overwrite an existing journal (the operator's record is
operator-owned), and --check verifies a machine-generated journal's
counts against the real git/checkin/timeline records.
"""

import importlib.machinery
import importlib.util
import tempfile
import unittest
import zipfile
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = ROOT / "scripts" / "generate-publication"


def load():
    loader = importlib.machinery.SourceFileLoader("gen_pub", str(SCRIPT))
    spec = importlib.util.spec_from_loader("gen_pub", loader)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def run(args):
    return subprocess.run([sys.executable, str(SCRIPT), *args],
                          capture_output=True, text=True, cwd=ROOT)


class JournalLifecycle(unittest.TestCase):
    def test_daily_roundtrip_and_check(self):
        mod = load()
        with tempfile.TemporaryDirectory() as td:
            mod.JOURNAL_DIR = Path(td)
            day = "2026-08-20"
            path = mod.journal_path(day)
            path.write_text(mod.build_journal(day))
            self.assertEqual(mod.check_day(day), 0)
            # operator-authored format (no machine ledger lines) refuses
            path.write_text("# Journal — 2026-08-20\n\nNot machine-formatted.\n")
            self.assertEqual(mod.check_day(day), 1)

    def test_existing_journal_refuses_overwrite(self):
        mod = load()
        with tempfile.TemporaryDirectory() as td:
            mod.JOURNAL_DIR = Path(td)
            day = "2026-08-20"
            path = mod.journal_path(day)
            path.write_text("# already here\n")
            self.assertEqual(mod.check_day(day), 1)  # drifted/not machine
            # the CLI refuses to overwrite without --force
            self.assertEqual(mod.main(["--daily", day]), 1)
            # with --force it regenerates and checks clean
            self.assertEqual(mod.main(["--daily", day, "--force"]), 0)
            self.assertEqual(mod.main(["--check", day]), 0)

    def test_book_assembles_epub(self):
        mod = load()
        with tempfile.TemporaryDirectory() as td:
            epub, book = mod.build_ebook(td)
            self.assertTrue(book.exists())
            with zipfile.ZipFile(epub) as z:
                names = z.namelist()
                self.assertIn("mimetype", names)
                self.assertIn("OEBPS/content.opf", names)
                self.assertIn("OEBPS/chapter.xhtml", names)
            self.assertIn("The intent", book.read_text())

    def test_site_index(self):
        mod = load()
        with tempfile.TemporaryDirectory() as td:
            index = mod.build_site(td)
            html = index.read_text()
            self.assertIn("<!doctype html>", html)
            self.assertIn("leaderboard", html)
            self.assertIn("instance interaction", html)


if __name__ == "__main__":
    unittest.main(verbosity=2)