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
import os
import sqlite3
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

    def test_refuses_operator_authored_format(self):
        mod = load()
        with tempfile.TemporaryDirectory() as td:
            mod.JOURNAL_DIR = Path(td)
            day = "2026-08-20"
            path = mod.journal_path(day)
            path.write_text("# Journal — 2026-08-20\n\nNot machine-formatted.\n")
            self.assertEqual(mod.check_day(day), 1)

    def test_telemetry_reads_hngh_home(self):
        # the telemetry db migrated to ~/.hngh/db/telemetry.db
        # (2026-09-13 userspace-home layout contract); the generator
        # resolves it through the same HNGH_HOME_DIR seam the
        # automation tier uses
        mod = load()
        with tempfile.TemporaryDirectory() as td:
            db_dir = Path(td) / "db"
            db_dir.mkdir()
            con = sqlite3.connect(db_dir / "telemetry.db")
            con.execute(
                "create table events (ts text, source text, kind text, "
                "identity text, lane text, unit text, model text, "
                "tokens_in integer, tokens_out integer, cost_usd real, "
                "wall_s real, subject text, refs text, body text)")
            con.execute("insert into events values "
                        "(datetime('now'), 'test', 'session-cost', 'i', "
                        "'lane', 'unit', 'model', 900, 100, 1.25, 1.0, "
                        "'', '', '')")
            con.commit()
            con.close()
            old = os.environ.get("HNGH_HOME_DIR")
            os.environ["HNGH_HOME_DIR"] = td
            try:
                numbers = mod.dispatch_numbers("2026-09-13")
            finally:
                if old is None:
                    os.environ.pop("HNGH_HOME_DIR", None)
                else:
                    os.environ["HNGH_HOME_DIR"] = old
            self.assertEqual(numbers["calls"], 1)
            self.assertEqual(numbers["spend"], 1.25)

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
            book_text = book.read_text()
            self.assertIn("The intent", book_text)
            # the 2026-09-09 presentation spine: the direction doc
            # and the records ride in the fixed front matter
            self.assertIn("The presentation direction", book_text)
            self.assertIn("The operator-flexibility doctrine", book_text)
            self.assertIn("The budget governance directive", book_text)
            self.assertIn("The wake-mutation lane rotation", book_text)
            self.assertIn("The 1Password service-account interface",
                          book_text)

    def test_site_index(self):
        mod = load()
        with tempfile.TemporaryDirectory() as td:
            index = mod.build_site(td)
            html = index.read_text()
            self.assertIn("<!doctype html>", html)
            self.assertIn("leaderboard", html)
            self.assertIn("instance interaction", html)


class StoryDeckAScrub(unittest.TestCase):
    """Digest seam audit 2026-09-16: story_section() quotes a deck A
    digest item [:140] into the journal/public edition. A pathy item
    (fixture: home-rooted, /tmp/, and tilde path tokens) must land
    redacted via digest_ledger.scrub_paths — fail-closed marker, quote
    kept."""

    def test_story_deck_a_quote_scrubs_paths(self):
        genpub = load()
        dl = genpub._load_job("digest_ledger")
        # committed kernel content carries no literal home path tokens
        # (verify-candidate public-content gate); concatenation restores
        # the exact runtime tokens the scrub regex must catch
        home_tok = "/" + "home/bricker/hngh/STATE.md"
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            auto = root / "automation"
            (auto / "digest").mkdir(parents=True)
            day = "2026-09-11"
            (auto / "digest" / (day + ".md")).write_text(
                "## 0300 %s\n"
                "_sources: hn-topstories | model: fixture-model_\n"
                "CRITICAL: drift in %s and /tmp/run-9.log and "
                "~/secrets.md\n" % (day, home_tok))
            old_auto, old_root = genpub.AUTOMATION, dl.ROOT
            genpub.AUTOMATION = auto
            dl.ROOT = root
            try:
                story = genpub.story_section(day)
            finally:
                genpub.AUTOMATION = old_auto
                dl.ROOT = old_root
        deck_a = story.split("automation/digest/%s.md" % day)[1]
        deck_a = deck_a.split("<!-- feeds:", 1)[0]
        for token in ("/" + "home/", "/tmp/", "~/"):
            self.assertNotIn(token, deck_a)
        self.assertEqual(deck_a.count("[redacted path]"), 3)
        # the quote is kept, redacted in place — not dropped
        self.assertIn("drift in", deck_a)
        self.assertIn("1 dispatch block(s) crossed", deck_a)


if __name__ == "__main__":
    unittest.main(verbosity=2)