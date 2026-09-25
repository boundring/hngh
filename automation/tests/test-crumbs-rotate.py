#!/usr/bin/env python3
"""test-crumbs-rotate — P1c rotation semantics: crumbs.db keeps
alert/finding/decision rows forever, prunes other rows past the window
ONLY after archiving them, and never deletes without an archive."""

import importlib.util
import os
import sqlite3
import tempfile
import unittest
from datetime import datetime, timedelta, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

_spec = importlib.util.spec_from_file_location(
    "crumbs_db_rotate", os.path.join(ROOT, "lib", "crumbs-db.py"))
MOD = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(MOD)


def _mkdb(path, rows):
    conn = sqlite3.connect(path)
    MOD._ensure(conn)
    conn.executemany(
        "INSERT INTO crumbs(ts, job, event, detail, writer) VALUES(?,?,?,?,?)",
        rows)
    conn.commit()
    conn.close()
    return path


def _events(path):
    conn = sqlite3.connect(path)
    out = [r[0] for r in conn.execute(
        "SELECT event FROM crumbs ORDER BY rowid").fetchall()]
    conn.close()
    return out


class Rotate(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix="crumbs-rotate-")
        self.db = os.path.join(self.dir, "crumbs.db")
        self.arch = os.path.join(self.dir, "archive.tsv")

    def test_keeps_keep_events_and_archives_pruned_noise(self):
        _mkdb(self.db, [
            ("2020-01-01T00:00:00Z", "j", "mounted", "old noise", "w@1"),
            ("2020-01-01T00:00:00Z", "j", "alert", "old alert", "w@2"),
            ("2020-01-01T00:00:00Z", "j", "finding", "old finding", None),
            ("2020-01-01T00:00:00Z", "j", "decision", "old decision", "w@3"),
            ("2099-01-01T00:00:00Z", "j", "mounted", "fresh noise", "w@4")])
        self.assertEqual(MOD.rotate(self.db, days=14, archive=self.arch), 1)
        self.assertEqual(_events(self.db),
                         ["alert", "finding", "decision", "mounted"])
        arch = open(self.arch, encoding="utf-8").read()
        self.assertIn("mounted | old noise [w=w@1]", arch)
        self.assertNotIn("old alert", arch)
        self.assertNotIn("old finding", arch)
        self.assertNotIn("old decision", arch)

    def test_no_archive_deletes_nothing(self):
        _mkdb(self.db, [("2020-01-01T00:00:00Z", "j", "mounted", "old", None)])
        self.assertEqual(MOD.rotate(self.db, days=14, archive=None), 0)
        self.assertEqual(_events(self.db), ["mounted"])

    def test_fourteen_day_window(self):
        old = (datetime.now(timezone.utc) - timedelta(days=15)
               ).strftime("%Y-%m-%dT%H:%M:%SZ")
        fresh = (datetime.now(timezone.utc) - timedelta(days=13)
                 ).strftime("%Y-%m-%dT%H:%M:%SZ")
        _mkdb(self.db, [(old, "j", "mounted", "aged out", None),
                        (fresh, "j", "mounted", "in window", None)])
        self.assertEqual(MOD.rotate(self.db, days=14, archive=self.arch), 1)
        self.assertEqual(_events(self.db), ["mounted"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
