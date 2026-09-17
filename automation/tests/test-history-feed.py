#!/usr/bin/env python3
"""Fixture tests for the history/1 merged-feed producer (jobs/history-feed.py).

Hermetic: tmpdir fixtures only — a fake git repo (subprocess git init +
dated commits), a fake reports.md ledger table, fake docs/records/ and
docs/journal/ trees. No network, no dashboard server, no kernel imports.

Contract (specs: .agent-scratch/swarm-resume/hist-windows-*.md):
- envelope exactly {"schema": "history/1", "entries": [...]}, entries flat
- per-source caps: gitlog 200, report 50, records 30, journal 14, total 500
- newest-wins truncation (sort ts desc, tie-break key asc, keep head)
- keys unique and prefix-tagged; gitlog keys are gitlog:<40-hex>
- ts Z-normalized; records/journal at T00:00:00Z
- records README.md excluded; report summary cut at 200 chars + "..."
- empty window emits the valid empty envelope
"""

import importlib.util
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JOBS = ROOT / "jobs"

_SPEC = importlib.util.spec_from_file_location(
    "history_feed", JOBS / "history-feed.py")
history_feed = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(history_feed)

_SCHEMA_SPEC = importlib.util.spec_from_file_location(
    "viz_schema", JOBS / "viz_schema.py")
viz_schema = importlib.util.module_from_spec(_SCHEMA_SPEC)
_SCHEMA_SPEC.loader.exec_module(viz_schema)


def validate(payload):
    """Round-trip + shared-validator check; returns (ok, detail)."""
    text = json.loads(json.dumps(payload))  # round-trip discipline
    ok, detail, _warn = viz_schema.validate_history(json.dumps(text))
    return ok, detail


def _git(repo, *args, date=None):
    env = dict(subprocess.os.environ)
    # containment: never inherit repo-selection vars from the caller's
    # shell (an exported GIT_DIR would redirect the fixture commits
    # elsewhere; 2026-09-17 kernel-contamination lesson)
    for hostile in ("GIT_DIR", "GIT_WORK_TREE"):
        env.pop(hostile, None)
    if date:
        env["GIT_AUTHOR_DATE"] = env["GIT_COMMITTER_DATE"] = date
    env.setdefault("GIT_CONFIG_GLOBAL", "/dev/null")
    env.setdefault("GIT_CONFIG_SYSTEM", "/dev/null")
    subprocess.run(["git", "-C", str(repo)] + list(args), check=True,
                   capture_output=True, text=True, env=env)


def _commit(repo, name, date, msg):
    (repo / name).write_text(name)
    _git(repo, "add", ".", date=date)
    _git(repo, "commit", "-m", msg, date=date)


class FixtureBase(unittest.TestCase):
    def make_root(self, with_git=True):
        tmp = tempfile.mkdtemp(prefix="hist-feed-")
        root = Path(tmp)
        (root / "docs" / "records").mkdir(parents=True)
        (root / "docs" / "journal").mkdir()
        (root / "docs" / "project").mkdir()
        (root / "docs" / "project" / "report-bodies").mkdir()
        if with_git:
            _git(root, "init", "-q", "-b", "main")
            _git(root, "config", "user.email", "fixture@example.com")
            _git(root, "config", "user.name", "Fixture")
        return root


class TestEmptyWindow(FixtureBase):
    def test_empty_sources_emit_valid_empty_envelope(self):
        root = self.make_root(with_git=False)
        feed = history_feed.build(root, now=history_feed._parse_z(
            "2026-09-15T12:00:00Z"))
        self.assertEqual(feed["schema"], "history/1")
        self.assertEqual(feed["entries"], [])
        ok, detail = validate(feed)
        self.assertTrue(ok, detail)


class TestGitlogSource(FixtureBase):
    def test_entries_and_shape(self):
        root = self.make_root()
        # oldest first: git --since stops traversal at the first too-old
        # commit, so HEAD must be newer than the window (real-repo shape).
        _commit(root, "c.txt", "2020-01-01T00:00:00 +0000",
                "ancient: outside 7d window")
        _commit(root, "a.txt", "2026-09-14T10:00:00 -0400",
                "old: inside window")
        _commit(root, "b.txt", "2026-09-20T12:00:00 +0000",
                "new: newest commit")
        now = history_feed._parse_z("2026-09-21T00:00:00Z")
        feed = history_feed.build(root, now=now)
        git_entries = [e for e in feed["entries"]
                       if e.get("source") == "gitlog"]
        self.assertEqual(len(git_entries), 2)  # ancient commit windowed out
        for e in git_entries:
            self.assertRegex(e["key"], r"^gitlog:[0-9a-f]{40}$")
            self.assertRegex(e["ts"], r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
            self.assertEqual(e["author"], "Fixture")
            self.assertRegex(e["short"], r"^[0-9a-f]{7,8}$")
            self.assertNotIn("ref", e)
        # newest first
        self.assertEqual(git_entries[0]["summary"], "new: newest commit")
        ok, detail = validate(feed)
        self.assertTrue(ok, detail)

    def test_cap_newest_wins(self):
        root = self.make_root()
        cap = history_feed.HIST_CAP_GITLOG
        for i in range(cap + 5):
            _commit(root, "f%d.txt" % i, "2026-09-15T00:%02d:%02d +0000"
                    % (i // 60, i % 60), "commit %03d" % i)
        feed = history_feed.build(root, now=history_feed._parse_z(
            "2026-09-16T00:00:00Z"))
        git_entries = [e for e in feed["entries"]
                       if e.get("source") == "gitlog"]
        self.assertEqual(len(git_entries), cap)
        summaries = [e["summary"] for e in git_entries]
        # newest-wins: the cap+5 commit survived, the oldest dropped
        self.assertIn("commit %03d" % (cap + 4), summaries)
        self.assertNotIn("commit 000", summaries)


class TestReportsSource(FixtureBase):
    def make_reports(self, root, rows):
        lines = ["# reports", "",
                 "| timestamp | kind | id | first line | body |",
                 "|---|---|---|---|---|"]
        lines += rows
        (root / "docs" / "project" / "reports.md").write_text(
            "\n".join(lines) + "\n")

    def test_report_rows(self):
        root = self.make_root(with_git=False)
        sidecar = "2026-09-15T12:00:00Z-progress-3e1a77b2.md"
        (root / "docs" / "project" / "report-bodies" / sidecar).write_text("x")
        self.make_reports(root, [
            "| 2026-09-15T12:00:00Z | progress | 3e1a77b2 | did the thing "
            "| %s |" % sidecar,
            "| 2026-09-15T11:00:00Z | alert | aaaabbcc | " + "x" * 250
            + " | missing.md |",
            "| 2026-09-10T09:00:00Z | progress | deadbeef | pruned row "
            "| prune-archive-2026-09-10.md |",
        ])
        feed = history_feed.build(root, now=history_feed._parse_z(
            "2026-09-15T13:00:00Z"))
        rep = [e for e in feed["entries"] if e.get("source") == "report"]
        self.assertEqual(len(rep), 2)  # prune-archive row skipped
        by_key = {e["key"]: e for e in rep}
        e1 = by_key["report:2026-09-15T12:00:00Z-progress-3e1a77b2"]
        self.assertEqual(e1["ts"], "2026-09-15T12:00:00Z")
        self.assertEqual(e1["kind"], "progress")
        self.assertEqual(e1["summary"], "did the thing")
        self.assertEqual(
            e1["ref"],
            "docs/project/report-bodies/"
            "2026-09-15T12:00:00Z-progress-3e1a77b2.md")
        e2 = by_key["report:2026-09-15T11:00:00Z-alert-aaaabbcc"]
        self.assertEqual(e2["summary"], "x" * 200 + "...")
        ok, detail = validate(feed)
        self.assertTrue(ok, detail)

    def test_report_cap_newest_wins(self):
        root = self.make_root(with_git=False)
        rows = []
        for i in range(history_feed.HIST_CAP_REPORT + 10):
            ts = "2026-09-15T%02d:%02d:00Z" % (i // 60, i % 60)
            rows.append("| %s | progress | id%05d | row %05d | s%05d.md |"
                        % (ts, i, i, i))
        self.make_reports(root, rows)
        feed = history_feed.build(root, now=history_feed._parse_z(
            "2026-09-16T00:00:00Z"))
        rep = [e for e in feed["entries"] if e.get("source") == "report"]
        self.assertEqual(len(rep), history_feed.HIST_CAP_REPORT)
        self.assertIn("report:2026-09-15T00:59:00Z-progress-id00059",
                      [e["key"] for e in rep])  # newest survives
        self.assertNotIn("report:2026-09-15T00:09:00Z-progress-id00009",
                         [e["key"] for e in rep])  # oldest dropped


class TestRecordsSource(FixtureBase):
    def test_records_entries_readme_excluded(self):
        root = self.make_root(with_git=False)
        rec = root / "docs" / "records"
        (rec / "README.md").write_text("index")
        (rec / "2026-09-15-viz-schema-version-gate.md").write_text("x")
        (rec / "2026-09-10-older-thing.md").write_text("x")
        (rec / "notes.txt").write_text("not a record")
        feed = history_feed.build(root, now=history_feed._parse_z(
            "2026-09-16T00:00:00Z"))
        recs = [e for e in feed["entries"] if e.get("source") == "records"]
        self.assertEqual(len(recs), 2)
        self.assertEqual(recs[0]["key"],
                         "records:2026-09-15-viz-schema-version-gate")
        self.assertEqual(recs[0]["ts"], "2026-09-15T00:00:00Z")
        self.assertEqual(recs[0]["summary"], "viz-schema-version-gate")
        self.assertEqual(recs[0]["ref"],
                         "docs/records/2026-09-15-viz-schema-version-gate.md")
        self.assertNotIn("README", json.dumps(feed))
        ok, detail = validate(feed)
        self.assertTrue(ok, detail)

    def test_records_cap(self):
        root = self.make_root(with_git=False)
        rec = root / "docs" / "records"
        for i in range(history_feed.HIST_CAP_RECORDS + 10):
            (rec / ("2026-09-%02d-rec%02d.md" % (i // 30 + 1, i))).write_text("x")
        feed = history_feed.build(root, now=history_feed._parse_z(
            "2026-10-01T00:00:00Z"))
        recs = [e for e in feed["entries"] if e.get("source") == "records"]
        self.assertEqual(len(recs), history_feed.HIST_CAP_RECORDS)
        keys = [e["key"] for e in recs]
        # 2026-09-02 has 10 records (rec30..rec39), 2026-09-01 has 30:
        # newest-wins keeps all ten 09-02 entries plus the newest 20 of 09-01.
        self.assertIn("records:2026-09-02-rec39", keys)  # newest survives
        # all 09-01 records share one ts, so the key-asc tie-break keeps
        # rec00..rec19; rec20..rec29 are the dropped tail of that day.
        self.assertIn("records:2026-09-01-rec00", keys)
        self.assertNotIn("records:2026-09-01-rec29", keys)


class TestJournalSource(FixtureBase):
    def test_journal_entries(self):
        root = self.make_root(with_git=False)
        (root / "docs" / "journal" / "2026-09-15.md").write_text("x")
        (root / "docs" / "journal" / "2026-09-14.md").write_text("x")
        feed = history_feed.build(root, now=history_feed._parse_z(
            "2026-09-16T00:00:00Z"))
        jr = [e for e in feed["entries"] if e.get("source") == "journal"]
        self.assertEqual(len(jr), 2)
        self.assertEqual(jr[0]["key"], "journal:2026-09-15")
        self.assertEqual(jr[0]["ts"], "2026-09-15T00:00:00Z")
        self.assertEqual(jr[0]["summary"], "daily journal 2026-09-15")
        self.assertEqual(jr[0]["ref"], "docs/journal/2026-09-15.md")
        ok, detail = validate(feed)
        self.assertTrue(ok, detail)


class TestMergedFeed(FixtureBase):
    def test_ordering_dedup_and_total_cap(self):
        root = self.make_root()
        _commit(root, "a.txt", "2026-09-15T12:00:00 +0000", "merge me")
        (root / "docs" / "records" / "2026-09-15-a-record.md").write_text("x")
        (root / "docs" / "journal" / "2026-09-15.md").write_text("x")
        (root / "docs" / "project" / "reports.md").write_text(
            "# reports\n\n| timestamp | kind | id | first line | body |\n"
            "|---|---|---|---|---|\n"
            "| 2026-09-15T13:00:00Z | progress | cafecafe | a report | s.md |\n")
        feed = history_feed.build(root, now=history_feed._parse_z(
            "2026-09-16T00:00:00Z"))
        entries = feed["entries"]
        keys = [e["key"] for e in entries]
        self.assertEqual(len(keys), len(set(keys)))  # dedup: unique keys
        # ts desc ordering with date-precision sources at T00:00:00Z first
        self.assertEqual(entries[-2]["key"], "journal:2026-09-15")
        self.assertEqual(entries[-1]["key"], "records:2026-09-15-a-record")
        pairs = [(e["ts"], e["key"]) for e in entries]
        # key asc within an equal-ts group (tie-break), ts desc across:
        # same two-pass sort the producer uses.
        by_key = sorted(pairs, key=lambda p: p[1])
        expected = sorted(by_key, key=lambda p: p[0], reverse=True)
        self.assertEqual(pairs, expected)
        self.assertLessEqual(len(entries), history_feed.HIST_CAP_TOTAL)
        ok, detail = validate(feed)
        self.assertTrue(ok, detail)


if __name__ == "__main__":
    unittest.main(verbosity=2)
