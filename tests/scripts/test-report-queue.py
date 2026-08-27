#!/usr/bin/env python3
"""Report queue smoke: the append-only ledger's CLI contract, hermetic.

Everything runs through the real script in a disposable temp root
(HNGH_REPORT_ROOT), so no repo file is touched and no network is used.
Contract: --add writes a row + body and refuses a bad kind / empty text
(exit 2); --list and --list KIND are newest-first; --json carries rows,
an unread count, and a per-kind summary; --unread without a cursor
returns every row and advances only via --mark-read.
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = ROOT / "scripts" / "report-queue"


def run(root, *args):
    env = dict(os.environ)
    env["HNGH_REPORT_ROOT"] = str(root)
    return subprocess.run([sys.executable, str(SCRIPT), *args],
                          capture_output=True, text=True, env=env)


class ReportQueueCLI(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name)

    def tearDown(self):
        self._td.cleanup()

    def reports_path(self):
        return self.root / "docs" / "project" / "reports.md"

    def bodies(self):
        d = self.root / "docs" / "project" / "report-bodies"
        return sorted(p.name for p in d.glob("*.md")) if d.exists() else []

    def add(self, kind, text, identity=None, window=None):
        args = ["--add", kind, text]
        if identity is not None:
            args += ["--identity", identity]
        if window is not None:
            args += ["--window", str(window)]
        return run(self.root, *args)

    def rows(self):
        out = []
        for line in self.reports_path().read_text().splitlines():
            s = line.strip()
            cells = ([c.strip() for c in s.strip("|").split("|")]
                     if s.startswith("|") and s.endswith("|") else None)
            if cells and len(cells) == 5 and cells[0] != "timestamp":
                out.append(cells)
        return out

    def backdate_all(self, ts="2020-01-01T00:00:00Z"):
        """Rewrite every row ts (and its body filename) to ts, for tests."""
        p = self.reports_path()
        d = self.root / "docs" / "project" / "report-bodies"
        lines = p.read_text().splitlines()
        for i, line in enumerate(lines):
            s = line.strip()
            cells = ([c.strip() for c in s.strip("|").split("|")]
                     if s.startswith("|") and s.endswith("|") else None)
            if (cells and len(cells) == 5 and cells[0] != ts
                    and cells[0] != "timestamp"):
                old = d / f"{cells[0]}-{cells[1]}-{cells[2]}.md"
                new = d / f"{ts}-{cells[1]}-{cells[2]}.md"
                if old.exists():
                    old.rename(new)
                cells[0] = ts
                lines[i] = "| " + " | ".join(cells) + " |"
        p.write_text("\n".join(lines) + "\n")

    def test_help_exits_zero(self):
        out = run(self.root, "--help")
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("report-queue", out.stdout)

    def test_add_writes_row_and_body(self):
        out = self.add("progress", "Wired the report queue end to end.")
        self.assertEqual(out.returncode, 0, out.stderr)
        text = self.reports_path().read_text()
        self.assertTrue(text.startswith("| timestamp | kind | id | first line | body |"))
        row = next(l for l in text.splitlines() if "Wired the" in l)
        cells = [c.strip() for c in row.strip("|").split("|")]
        self.assertEqual(cells[1], "progress")
        self.assertEqual(cells[3], "Wired the report queue end to end.")
        self.assertEqual(len(self.bodies()), 1, "one body file written")
        self.assertIn("Wired the report queue", self.bodies_md())

    def bodies_md(self):
        d = self.root / "docs" / "project" / "report-bodies"
        return (d / self.bodies()[0]).read_text()

    def test_list_is_newest_first_and_filters_by_kind(self):
        self.add("progress", "alpha progress")
        self.add("alert", "alpha alert")
        self.add("progress", "beta progress")
        out = run(self.root, "--list")
        self.assertEqual(out.returncode, 0, out.stderr)
        lines = [l for l in out.stdout.splitlines() if l.startswith("|")]
        self.assertEqual(len(lines), 3)
        # newest first: the last-added progress row is top
        self.assertIn("beta progress", lines[0])
        self.assertIn("alpha progress", lines[2])
        filt = run(self.root, "--list", "alert")
        flines = [l for l in filt.stdout.splitlines() if l.startswith("|")]
        self.assertEqual(len(flines), 1)
        self.assertIn("alpha alert", flines[0])

    def test_unread_missing_cursor_returns_rows_then_mark_read_advances(self):
        self.add("progress", "first")
        self.add("alert", "second")
        before = [l for l in run(self.root, "--unread").stdout.splitlines()
                  if l.startswith("|")]
        self.assertEqual(len(before), 2)
        # mark the first row read: unread should drop to the newer rows
        first_id = before[1].split(" | ")[2]  # newest-first, so last row is oldest
        out = run(self.root, "--mark-read", first_id)
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertEqual(self.cursor().strip(), first_id)
        after = [l for l in run(self.root, "--unread").stdout.splitlines()
                 if l.startswith("|")]
        self.assertEqual(len(after), 1)

    def test_mark_read_unknown_refuses(self):
        out = run(self.root, "--mark-read", "deadbeef")
        self.assertEqual(out.returncode, 2)
        self.assertIn("unknown", out.stderr)

    def test_bad_kind_refuses(self):
        out = self.add("bogus", "x")
        self.assertEqual(out.returncode, 2)
        self.assertIn("bad kind", out.stderr)
        self.assertFalse(self.reports_path().exists())

    def test_empty_text_refuses(self):
        out = self.add("progress", "   ")
        self.assertEqual(out.returncode, 2)
        self.assertIn("empty TEXT", out.stderr)
        self.assertFalse(self.reports_path().exists())

    def test_json_carries_rows_summary_and_unread(self):
        self.add("progress", "json progress")
        self.add("alert", "json alert")
        out = run(self.root, "--json")
        self.assertEqual(out.returncode, 0, out.stderr)
        doc = json.loads(out.stdout)
        self.assertEqual(len(doc["reports"]), 2)
        self.assertEqual(doc["unread"], 2)
        self.assertEqual(doc["summary"]["progress"], 1)
        self.assertEqual(doc["summary"]["alert"], 1)
        self.assertIn("json alert", doc["reports"][0]["body"])
        self.assertIn("json progress", doc["reports"][1]["body"])
        # newest first in the dashboard payload too
        self.assertEqual(doc["reports"][0]["kind"], "alert")

    def test_identity_dedup_bumps_count_and_body(self):
        ident = "stale-store:/tmp/x"
        self.assertEqual(self.add("alert", "stale store detected",
                                  identity=ident).returncode, 0)
        out = self.add("alert", "stale store detected again", identity=ident)
        self.assertEqual(out.returncode, 0, out.stderr)
        rows = self.rows()
        self.assertEqual(len(rows), 1, "no new row on identity dedup")
        self.assertTrue(rows[0][3].endswith(" ×2"), rows[0])
        body = self.bodies_md()
        self.assertEqual(body.count(" occurrence"), 1, body)
        self.assertIn("- **identity:** " + ident, body)
        # third occurrence: ×3, and the marker replaces the old one
        self.assertEqual(self.add("alert", "third time", identity=ident)
                         .returncode, 0)
        rows = self.rows()
        self.assertEqual(len(rows), 1)
        self.assertTrue(rows[0][3].endswith(" ×3"))
        self.assertEqual(self.bodies_md().count(" occurrence"), 2)

    def test_identity_window_expiry_and_unlimited_zero(self):
        ident = "slow-unit:u1"
        self.assertEqual(self.add("progress", "slow unit", identity=ident,
                                  window=60).returncode, 0)
        self.backdate_all()  # row is now far older than any sane window
        out = self.add("progress", "slow unit", identity=ident, window=60)
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertEqual(len(self.rows()), 2, "expired window adds a new row")
        new_body = self.bodies_md()
        self.assertIn("- **identity:** " + ident, new_body)
        # --window 0 = unlimited lookback: the expired row still dedups
        out = self.add("progress", "slow unit again", identity=ident, window=0)
        self.assertEqual(out.returncode, 0, out.stderr)
        rows = self.rows()
        self.assertEqual(len(rows), 2)
        self.assertTrue(rows[-1][3].endswith(" ×2"))

    def test_different_identity_adds_new_row(self):
        self.add("alert", "same text", identity="stale-store:/a")
        self.add("alert", "same text", identity="stale-store:/b")
        self.assertEqual(len(self.rows()), 2)

    def test_identity_dedup_scans_past_other_identities(self):
        """Alternating identities in one window: dedup, never duplicate."""
        ia, ib = "stale-store:/a", "slow-unit:/b"
        self.add("alert", "alpha text", identity=ia)
        self.add("alert", "beta text", identity=ib)
        self.add("alert", "alpha again", identity=ia)
        self.add("alert", "beta again", identity=ib)
        rows = self.rows()
        self.assertEqual(len(rows), 2, "no third row for a repeat identity")
        markers = sorted(r[3].rsplit(" ×", 1) for r in rows)
        self.assertEqual([base for base, _ in markers], ["alpha text", "beta text"])
        self.assertEqual([n for _, n in markers], ["2", "2"])
        for ident in (ia, ib):
            hits = 0
            for name in self.bodies():
                text = (self.root / "docs" / "project" / "report-bodies"
                        / name).read_text()
                if "- **identity:** " + ident in text:
                    hits += 1
                    self.assertEqual(text.count(" occurrence"), 1, name)
            self.assertEqual(hits, 1, ident)

    def test_prune_removes_listed_kinds_deletes_bodies_and_archives(self):
        self.add("alert", "old alert one")
        self.add("alert", "old alert two")
        self.add("expense", "old expense")
        self.backdate_all()
        self.add("progress", "fresh progress")
        arch = self.root / "arch.md"
        out = run(self.root, "--prune", "--before", "2021-01-01T00:00:00Z",
                  "--kinds", "alert,expense", "--archive", str(arch))
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("pruned 3 rows, 3 bodies, archived to", out.stdout)
        remaining = self.rows()
        self.assertEqual(len(remaining), 1)
        self.assertEqual(remaining[0][1], "progress")
        self.assertEqual(len(self.bodies()), 1, "pruned bodies deleted")
        text = arch.read_text()
        self.assertIn("## pruned 2021-01-01T00:00:00Z", text)
        for gone in ("old alert one", "old alert two", "old expense"):
            self.assertIn(gone, text)
        self.assertNotIn("fresh progress", text)

    def test_prune_refuses_future_missing_or_bad_input(self):
        self.add("alert", "doomed")
        out = run(self.root, "--prune", "--before", "2999-01-01T00:00:00Z",
                  "--kinds", "alert")
        self.assertEqual(out.returncode, 2)
        self.assertIn("future", out.stderr)
        out = run(self.root, "--prune", "--kinds", "alert")
        self.assertEqual(out.returncode, 2)
        out = run(self.root, "--prune", "--before", "2021-01-01T00:00:00Z",
                  "--kinds", "bogus")
        self.assertEqual(out.returncode, 2)
        self.assertIn("bad kind", out.stderr)
        out = run(self.root, "--prune", "--before", "not-a-ts",
                  "--kinds", "alert")
        self.assertEqual(out.returncode, 2)
        self.assertEqual(len(self.rows()), 1, "nothing pruned on refusal")

    def test_help_documents_identity_and_prune(self):
        out = run(self.root, "--help")
        for token in ("--identity", "--window", "--prune", "--before",
                      "--kinds", "--archive", "occurrence"):
            self.assertIn(token, out.stdout)

    def cursor(self):
        p = self.root / "docs" / "project" / "report-cursor"
        return p.read_text() if p.exists() else ""


if __name__ == "__main__":
    unittest.main(verbosity=2)