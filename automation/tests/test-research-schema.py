#!/usr/bin/env python3
"""Research TSV schema contracts at gate time (db-migration slice A).

Grammar tests feed hermetic tmpdir TSVs through the REAL parser
(jobs/research-routes.py _read_tsv, importlib-loaded with the
established pattern from tests/test-routes-view.py). Live contracts
parse the actual research data and assert vocabulary/header acceptance
only — NEVER exact counts (the research beat appends hourly; exact
counts would red within the hour).

Boundary: schema/grammar only. Semantic checks (lineage, staleness)
are owned by jobs/patrol.py — deliberately not duplicated here.
"""

import importlib.util
import tempfile
import unittest
from pathlib import Path

AUTO_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = Path(__file__).resolve().parents[2]


def _load(name, rel):
    spec = importlib.util.spec_from_file_location(name, str(AUTO_ROOT / rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


rr = _load("research_routes", "jobs/research-routes.py")


def _write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text)


class Grammar(unittest.TestCase):
    """Hermetic tmpdir TSVs through the real parser."""

    def _tmp(self):
        return tempfile.TemporaryDirectory()

    def _path(self, td, name):
        return Path(td) / "automation" / name

    def test_header_drift_raises(self):
        with self._tmp() as td:
            p = self._path(td, "research-lessons.tsv")
            _write(p, "lesson_id\twrong\tline_id\tsubject\tlesson\tstatus\n")
            with self.assertRaises(ValueError):
                rr._read_tsv(p, rr.LESSONS_HEADER)

    def test_row_shorter_than_min_fields_raises(self):
        with self._tmp() as td:
            p = self._path(td, "research-dispositions.tsv")
            _write(p, "\t".join(rr.DISP_HEADER) + "\nl1\tkilled\n")
            with self.assertRaises(ValueError):
                rr._read_tsv(p, rr.DISP_HEADER, min_fields=3, pad_to=len(rr.DISP_HEADER))

    def test_over_wide_row_raises(self):
        with self._tmp() as td:
            p = self._path(td, "research-lessons.tsv")
            _write(p, "\t".join(rr.LESSONS_HEADER)
                   + "\nl1\t2026-09-22T00:00:00Z\tline\ts\tlesson\tactive\textra\n")
            with self.assertRaises(ValueError):
                rr._read_tsv(p, rr.LESSONS_HEADER)

    def test_pad_to_fills_legacy_short_rows(self):
        """The research-dispositions 3-5-field accommodation."""
        with self._tmp() as td:
            p = self._path(td, "research-dispositions.tsv")
            _write(p, "\t".join(rr.DISP_HEADER) + "\nl1\tadopted\tok\n")
            rows = rr._read_tsv(p, rr.DISP_HEADER, min_fields=3, pad_to=len(rr.DISP_HEADER))
            self.assertEqual(len(rows), 1)
            self.assertEqual(rows[0]["line"], "l1")
            self.assertEqual(rows[0]["verdict"], "ok")
            self.assertEqual(rows[0]["followons"], "")

    def test_comment_and_blank_lines_skipped(self):
        with self._tmp() as td:
            p = self._path(td, "research-lessons.tsv")
            header = "\t".join(rr.LESSONS_HEADER) + "\n"
            _write(p, "# a comment\n\n" + header
                      + "\n# another comment\n"
                      + "l1\t2026-09-22T00:00:00Z\tline\ts\tlesson\tactive\n")
            rows = rr._read_tsv(p, rr.LESSONS_HEADER)
            self.assertEqual([r["lesson_id"] for r in rows], ["l1"])

    def test_missing_file_returns_empty(self):
        """Fail-soft reader contract."""
        with self._tmp() as td:
            self.assertEqual(rr._read_tsv(Path(td) / "nope.tsv", rr.LESSONS_HEADER), [])


class LiveContracts(unittest.TestCase):
    """Real repo data through the same parser (snapshot-once reads:
    grammar membership only, never exact counts — the beat appends
    hourly).

    Deliberately omitted: live action-vocabulary assertion. One legacy
    disposition row carries action='fixed' (not in
    ROUTE_ACTIONS=adopted/parked/killed), and vocabulary enforcement
    belongs to the disposition writer, not this reader gate — recorded
    here rather than silently skipped."""

    def test_line_rows_parse_with_known_status_vocabulary(self):
        rows = rr.line_rows(REPO_ROOT)
        self.assertGreater(len(rows), 0)
        for row in rows.values():
            self.assertIn(row["status"], rr.STATUS_FAMILIES)

    def test_disposition_rows_parse_and_header_accepted(self):
        # Parser acceptance IS the header contract (drift raises); the
        # raw-header equality gives a precise failure message when it
        # does drift.
        rows = rr.disposition_rows(REPO_ROOT)
        self.assertGreater(len(rows), 0)
        header = (AUTO_ROOT / "research-dispositions.tsv").read_text().splitlines()[0]
        self.assertEqual(tuple(f.strip() for f in header.split("\t")), rr.DISP_HEADER)

    def test_lesson_line_ids_positive_and_live_header_exact(self):
        ids = rr.lesson_line_ids(REPO_ROOT)
        self.assertGreater(len(ids), 0)
        header = (AUTO_ROOT / "research-lessons.tsv").read_text().splitlines()[0]
        self.assertEqual(tuple(f.strip() for f in header.split("\t")), rr.LESSONS_HEADER)


if __name__ == "__main__":
    unittest.main()