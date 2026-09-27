#!/usr/bin/env python3
"""Hermetic tests for news-ingest.py (no network).

Feeds fixture RSS + Atom bodies through --source-dir with a sandboxed
HNGH_HOME_DIR, asserting category/feed mapping from the TSV, dedup by
link hash, the --limit cap, dead-feed fail-closed skipping, fetch_state
rows, and idempotent refresh.
"""
import hashlib
import os
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

AUTO = Path(__file__).resolve().parent.parent
INGEST = AUTO / "scripts" / "news-ingest.py"

CONFIG = (
    "# feed\tcategory\turl\tenabled\tweight\n"
    "test-rss\tworld\thttps://example.com/rss.xml\t1\t0.5\n"
    "test-atom\tpolitics\thttps://example.com/atom.xml\t1\t0.5\n"
    "test-dead\tscience\thttps://example.com/dead.xml\t1\t0.5\n"
)

RSS = """<?xml version="1.0"?>
<rss version="2.0"><channel><title>Test RSS</title>
<item><title>Alpha One</title><link>https://example.com/a1</link><description>first</description><pubDate>Mon, 21 Sep 2026 10:00:00 GMT</pubDate></item>
<item><title>Alpha Two</title><link>https://example.com/a2</link><description>second</description><pubDate>Tue, 22 Sep 2026 11:00:00 GMT</pubDate></item>
<item><title>Shared Item</title><link>https://example.com/shared</link><description>dup</description><pubDate>Wed, 23 Sep 2026 12:00:00 GMT</pubDate></item>
</channel></rss>
"""

ATOM = """<?xml version="1.0"?>
<feed xmlns="http://www.w3.org/2005/Atom"><title>Test Atom</title>
<entry><title>Beta One</title><link rel="alternate" href="https://example.com/b1"/><summary>beta summary</summary><published>2026-09-24T08:30:00Z</published></entry>
<entry><title>Shared Item</title><link href="https://example.com/shared"/><content>shared content</content><updated>2026-09-25T09:00:00Z</updated></entry>
</feed>
"""


def run(*argv, **env):
    e = dict(os.environ, **env)
    return subprocess.run([sys.executable, "-B", *map(str, argv)],
                          capture_output=True, text=True, env=e, timeout=60)


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="news-ingest-"))
        self.addCleanup(lambda: __import__("shutil").rmtree(self.tmp, True))
        self.src = self.tmp / "src"
        self.src.mkdir()
        (self.src / "test-rss").write_text(RSS)
        (self.src / "test-atom").write_text(ATOM)
        self.config = self.tmp / "news-feeds.tsv"
        self.config.write_text(CONFIG)
        self.home = self.tmp / "home"
        self.home.mkdir()
        self.db = self.tmp / "news.db"
        self.env = {"HNGH_HOME_DIR": str(self.home)}

    def ingest(self, *extra):
        argv = [INGEST, "--config", self.config, "--source-dir", self.src]
        if self.db is not None:
            argv += ["--db", self.db]
        return run(*argv, *extra, **self.env)

    def rows(self, sql):
        conn = sqlite3.connect(self.db)
        try:
            return conn.execute(sql).fetchall()
        finally:
            conn.close()


class TestIngest(Base):
    def test_ingest_categories_dedup_state(self):
        r = self.ingest()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(
            r.stdout, "news ingest: 2 feed(s) ok, 4 item(s), 1 skipped\n")
        rows = self.rows("SELECT id, feed, category, link, published"
                         " FROM items ORDER BY link")
        self.assertEqual(len(rows), 4)
        by_link = {row[3]: row for row in rows}
        # link shared by both fixture feeds -> one row, last writer wins
        self.assertEqual(by_link["https://example.com/shared"][1:3],
                         ("test-atom", "politics"))
        # category + feed columns come from the tsv
        self.assertEqual(by_link["https://example.com/a1"][1:3],
                         ("test-rss", "world"))
        self.assertEqual(by_link["https://example.com/b1"][1:3],
                         ("test-atom", "politics"))
        # id is the 8-hex sha256 of the link
        want = hashlib.sha256(b"https://example.com/a1").hexdigest()[:8]
        self.assertEqual(by_link["https://example.com/a1"][0], want)
        for row in rows:
            self.assertRegex(row[0], r"^[0-9a-f]{8}$")
        # RFC822 and Atom dates both normalised to ISO Z UTC
        self.assertEqual(by_link["https://example.com/a1"][4],
                         "2026-09-21T10:00:00Z")
        self.assertEqual(by_link["https://example.com/b1"][4],
                         "2026-09-24T08:30:00Z")
        # fetch_state written with NULL validators in fixture mode
        state = self.rows("SELECT feed, etag, last_modified, fetched"
                          " FROM fetch_state ORDER BY feed")
        self.assertEqual([s[0] for s in state], ["test-atom", "test-rss"])
        for _, etag, last_mod, fetched in state:
            self.assertIsNone(etag)
            self.assertIsNone(last_mod)
            self.assertRegex(fetched, r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")

    def test_dead_feed_skipped_good_feed_ingested(self):
        r = self.ingest()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("test-dead", r.stderr)
        feeds = {row[0] for row in self.rows("SELECT DISTINCT feed FROM items")}
        self.assertEqual(feeds, {"test-rss", "test-atom"})

    def test_limit_caps_items_per_feed(self):
        r = self.ingest("--limit", "1")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(
            r.stdout, "news ingest: 2 feed(s) ok, 2 item(s), 1 skipped\n")
        links = sorted(row[0] for row in self.rows("SELECT link FROM items"))
        self.assertEqual(links, ["https://example.com/a1",
                                 "https://example.com/b1"])

    def test_second_run_no_duplicates(self):
        self.ingest()
        r2 = self.ingest()
        self.assertEqual(r2.returncode, 0, r2.stderr)
        self.assertEqual(
            r2.stdout, "news ingest: 2 feed(s) ok, 4 item(s), 1 skipped\n")
        self.assertEqual(len(self.rows("SELECT id FROM items")), 4)
        self.assertEqual(len(self.rows("SELECT feed FROM fetch_state")), 2)

    def test_default_db_lives_under_home(self):
        self.db = None
        r = self.ingest()
        self.assertEqual(r.returncode, 0, r.stderr)
        default = self.home / "db" / "hngh-news.db"
        self.assertTrue(default.exists())
        conn = sqlite3.connect(default)
        n = conn.execute("SELECT COUNT(*) FROM items").fetchone()[0]
        conn.close()
        self.assertEqual(n, 4)


if __name__ == "__main__":
    unittest.main()
