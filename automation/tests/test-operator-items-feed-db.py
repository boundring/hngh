#!/usr/bin/env python3
"""operator-items-feed crumbs() reader flip: the crumbs journal db is the
source of truth. crumbs() must yield exactly the 4-tuples the old STATE.md
parse yielded (detail keeps its [w=...] stamp tail), and a missing or
broken journal must leave the prior operator-items.json untouched."""

import importlib.util
import json
import os
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
        self.addCleanup(os.environ.pop, "HNGH_CRUMBS_DB", None)
        self.state = os.path.join(self.tmp.name, "STATE.md")
        self.db = os.path.join(self.tmp.name, "crumbs.db")
        os.environ["HNGH_CRUMBS_DB"] = self.db
        self.rows = [
            "2026-09-25T01:00:00Z | patrol.py | alert | first-line of the alert",
            "2026-09-25T02:00:00Z | imap-poll.py | papercut | dashboard header needs operator decision",
            "2026-09-25T03:00:00Z | cadence-tick.sh | mounted | otherwise nothing to see here",
        ]
        self.write_state(self.rows)
        self.feed = _load_feed()

    def write_state(self, rows):
        # fixture STATE.md -> sandbox crumbs journal (fresh db: the sync
        # watermark is a byte offset, so re-imports need a clean db)
        with open(self.state, "w", encoding="utf-8") as f:
            f.write("\n".join(rows) + "\n")
        if os.path.exists(self.db):
            os.unlink(self.db)
        subprocess.run([sys.executable, os.path.join(ROOT, "lib", "crumbs-db.py"),
                        "sync", "--state", self.state, "--db", self.db],
                       check=True, capture_output=True)

    def test_db_rows_match_state_rows(self):
        # byte-parity with the old STATE.md parse output shape
        self.assertEqual(self.feed.crumbs(), [
            ("2026-09-25T01:00:00Z",
             "patrol.py | alert | first-line of the alert",
             "alert", "first-line of the alert"),
            ("2026-09-25T02:00:00Z",
             "imap-poll.py | papercut | dashboard header needs operator decision",
             "papercut", "dashboard header needs operator decision"),
            ("2026-09-25T03:00:00Z",
             "cadence-tick.sh | mounted | otherwise nothing to see here",
             "mounted", "otherwise nothing to see here"),
        ])

    def test_stamped_rows_keep_the_stamp_tail(self):
        # legacy [w=name@rowid] tails import into the writer column and
        # reconstruct into detail + joined text (item ids hash that text)
        self.write_state(self.rows + [
            "2026-09-25T04:00:00Z | patrol.py | alert | stale store [w=patrol.py@17]",
        ])
        rows = self.feed.crumbs()
        self.assertEqual(len(rows), 4)
        self.assertEqual(rows[-1], (
            "2026-09-25T04:00:00Z",
            "patrol.py | alert | stale store [w=patrol.py@17]",
            "alert", "stale store [w=patrol.py@17]"))

    def test_alert_and_keyword_only(self):
        rows = self.feed.crumbs()
        items = [r for r in rows if self.feed.is_operator_item(r[2], r[1])]
        self.assertEqual(len(items), 2)

    def test_broken_db_keeps_prior_file(self):
        # the db is source of truth — the fallback parse is gone; an
        # unavailable journal must fail closed, keeping the prior file
        with open(os.path.join(self.tmp.name, "data.json"), "w") as f:
            f.write("{}")
        self.feed.DATA = os.path.join(self.tmp.name, "data.json")
        self.feed.OUT = os.path.join(self.tmp.name, "operator-items.json")
        self.feed.DISMISSED = os.path.join(self.tmp.name, "dismissed.json")
        self.feed.APPROVED = os.path.join(self.tmp.name, "approved.json")
        prior = '{"items": [{"id": "deadbeef", "text": "prior item"}]}'
        with open(self.feed.OUT, "w") as f:
            f.write(prior)
        os.unlink(self.db)  # missing journal
        self.feed.main()
        with open(self.feed.OUT) as f:
            self.assertEqual(f.read(), prior)
        with open(self.db, "w") as f:
            f.write("not a database\n")  # broken journal
        self.feed.main()
        with open(self.feed.OUT) as f:
            self.assertEqual(f.read(), prior)


class ResiduePurge(unittest.TestCase):
    """operator-directed purge 2026-09-27: the '[feedback:idea] from
    email' test residue must never file — its [w=...] stamp tails give
    every rebuild fresh ids, resurrecting dismissed rows; a full main()
    run over a residue-seeded journal drops them while real rows and
    rerun-idempotence survive."""

    RESIDUE = ("2026-09-27T13:36:0%dZ | report-queue | alert | "
               "[feedback:idea] from email [w=crumbs.py@%d]")
    REAL = ("2026-09-27T13:37:00Z | report-queue | alert | "
            "[feedback:idea] please make the masthead darker")
    OTHER = ("2026-09-27T13:38:00Z | patrol.py | alert | stale store "
             "needs operator decision")

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.addCleanup(os.environ.pop, "HNGH_CRUMBS_DB", None)
        self.state = os.path.join(self.tmp.name, "STATE.md")
        self.db = os.path.join(self.tmp.name, "crumbs.db")
        os.environ["HNGH_CRUMBS_DB"] = self.db
        self.feed = _load_feed()
        self.feed.DATA = os.path.join(self.tmp.name, "data.json")
        with open(self.feed.DATA, "w") as f:
            f.write("{}")
        self.feed.OUT = os.path.join(self.tmp.name, "operator-items.json")
        self.feed.DISMISSED = os.path.join(self.tmp.name, "dismissed.json")
        self.feed.APPROVED = os.path.join(self.tmp.name, "approved.json")
        self.sync(self.RESIDUE % (1, 401) + "\n" + self.REAL + "\n" +
                  self.RESIDUE % (2, 402) + "\n" + self.OTHER + "\n")

    def sync(self, state_text):
        with open(self.state, "w") as f:
            f.write(state_text)
        if os.path.exists(self.db):
            os.unlink(self.db)
        subprocess.run([sys.executable,
                        os.path.join(ROOT, "lib", "crumbs-db.py"),
                        "sync", "--state", self.state, "--db", self.db],
                       check=True, capture_output=True)

    def run_feed(self):
        self.feed.main()
        with open(self.feed.OUT) as f:
            items = json.load(f)["items"]
        return {it["id"]: it["text"] for it in items}

    def test_residue_never_filed_reals_survive_idempotent(self):
        items = self.run_feed()
        self.assertEqual(len(items), 2)  # residue rows 401/402 dropped
        for text in items.values():
            self.assertNotIn("[feedback:idea] from email", text)
        self.assertIn("masthead darker", " ".join(items.values()))
        self.assertIn("stale store", " ".join(items.values()))
        rerun = self.run_feed()  # rewrite, not merge: same ids again
        self.assertEqual(rerun, items)


if __name__ == "__main__":
    unittest.main()
