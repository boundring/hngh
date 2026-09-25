#!/usr/bin/env python3
"""operator-items-feed crumbs() reader flip: the derived index
(state/crumbs.db) must yield exactly the rows the STATE.md parse yields,
with an availability fallback to the parse when the index is unreadable."""

import importlib.util
import os
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _load_feed():
    spec = importlib.util.spec_from_file_location(
        "operator-items-feed",
        os.path.join(ROOT, "jobs", "operator-items-feed.py"))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class FeedDbFlip(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.state = os.path.join(self.tmp.name, "STATE.md")
        # crumbs() derives the index from the journal: <state dir>/state/crumbs.db
        statedir = os.path.join(self.tmp.name, "state")
        os.makedirs(statedir)
        self.db = os.path.join(statedir, "crumbs.db")
        rows = [
            "2026-09-25T01:00:00Z | patrol.py | alert | first-line of the alert",
            "2026-09-25T02:00:00Z | imap-poll.py | papercut | dashboard header needs operator decision",
            "2026-09-25T03:00:00Z | cadence-tick.sh | mounted | otherwise nothing to see here",
        ]
        with open(self.state, "w", encoding="utf-8") as f:
            f.write("\n".join(rows) + "\n")
        subprocess.run([sys.executable, os.path.join(ROOT, "lib", "crumbs-db.py"),
                        "sync", "--state", self.state, "--db", self.db],
                       check=True, capture_output=True)
        self.feed = _load_feed()
        self.feed.STATE = self.state
        self.feed.DB = self.db

    def test_db_rows_match_state_rows(self):
        self.assertEqual(self.feed.crumbs(), self.feed._crumbs_from_state())

    def test_alert_and_keyword_only(self):
        rows = self.feed.crumbs()
        items = [r for r in rows if self.feed.is_operator_item(r[2], r[1])]
        self.assertEqual(len(items), 2)

    def test_unreadable_index_falls_back_to_state(self):
        # the derived index path is unwritable (state/ exists as a file),
        # so sync fails and crumbs() must fall back to the STATE.md parse
        shutil.rmtree(os.path.join(self.tmp.name, "state"))
        with open(os.path.join(self.tmp.name, "state"), "w") as f:
            f.write("not a directory\n")
        self.assertEqual(self.feed.crumbs(), self.feed._crumbs_from_state())


if __name__ == "__main__":
    unittest.main()
