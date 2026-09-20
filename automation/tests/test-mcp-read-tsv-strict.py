#!/usr/bin/env python3
"""Strict-reader contract sketch for the MCP research TSV reader.

Spec: docs/design/strict-reader-spec.md (reader-audit-m::strict-reader-spec).

Two classes:

  CurrentSeams    PASSING characterization of today's fail-open /
                  fail-locked seams in
                  automation/mcp/hngh_mcp_server.py::read_tsv (each test
                  names its seam). Delete this class in the slice that
                  implements the strict contract.
  StrictContract  The target skip-and-count contract from the spec
                  (3-tuple return with counters, per-category skips,
                  fatal boundary, stderr logging). SKIPPED until the
                  reader lands; unskip it in the implementing slice and
                  delete CurrentSeams.

Hermetic: writes its TSVs under tempfile dirs, never touches
automation/research-*.tsv.
"""

import contextlib
import importlib.util
import io
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SERVER = ROOT / "mcp" / "hngh_mcp_server.py"

spec = importlib.util.spec_from_file_location("hngh_mcp_server", str(SERVER))
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)

GOOD_LINES_ROW = "aaa\tplanned\t2026-09-01T00:00:00Z\ttitle A"
DISP_HEADER = "line\taction\tverdict\treviewer\tevidence\tdate\tsupport\toppose\tfollowons"
GOOD_DISP_ROW = "aaa\tadopted\tkeep\trev\t/e\t2026-09-02\ts\to\tf"


def _td():
    return tempfile.TemporaryDirectory()


class CurrentSeams(unittest.TestCase):
    """Today's behavior, probed 2026-09-20 (spec section 7)."""

    def _file(self, data):
        td = tempfile.TemporaryDirectory()
        self.addCleanup(td.cleanup)
        path = Path(td.name) / "research-lines.tsv"
        path.write_bytes(data)
        return path

    def test_seam_overwide_row_kills_whole_call(self):
        # fail-locked: one 5-field row poisons the entire feed
        p = self._file((GOOD_LINES_ROW + "\n"
                        + "bbb\treviewed\t2026-09-02T00:00:00Z\tt\textra\n"
                        + GOOD_LINES_ROW + "\n").encode())
        with self.assertRaises(RuntimeError):
            mod.read_tsv(p, None)

    def test_seam_underwide_row_silently_missing_keys(self):
        # fail-open: a 3-field headerless row keeps, with keys silently
        # narrowed (no 'title' key at all)
        p = self._file(b"ccc\treviewed\t2026-09-02T00:00:00Z\n")
        rows, truncated = mod.read_tsv(p, None)
        self.assertEqual(len(rows), 1)
        self.assertNotIn("title", rows[0])

    def test_seam_comment_line_returned_as_data(self):
        # parity drift: research-routes.py/graph-data.py skip '#' lines
        p = self._file(b"# a comment\n" + GOOD_LINES_ROW.encode() + b"\n")
        rows, _ = mod.read_tsv(p, None)
        self.assertEqual(rows[0], {"line": "# a comment"})

    def test_seam_nul_passes_through(self):
        p = self._file(b"bbb\tcontracting\t2026-09-04T00:00:00Z\tti\x00tle\n")
        rows, _ = mod.read_tsv(p, None)
        self.assertEqual(rows[0]["title"], "ti\x00tle")

    def test_seam_embedded_cr_splits_row(self):
        # universal newlines turn a lone \r into a line break: one row
        # becomes two wrong rows
        p = self._file(b"aaa\tplanned\t2026-09-01T00:00:00Z\tA\rB\n")
        rows, _ = mod.read_tsv(p, None)
        self.assertEqual(len(rows), 2)

    def test_seam_blank_lines_dropped_uncounted(self):
        # 2-tuple signature seam: there is no counter to observe the
        # two dropped blank lines with
        p = self._file(b"\n\n" + GOOD_LINES_ROW.encode() + b"\n\n")
        result = mod.read_tsv(p, None)
        self.assertEqual(len(result), 2)  # (rows, truncated) only
        self.assertEqual(len(result[0]), 1)

    def test_seam_headered_underwide_silently_missing_keys(self):
        td = tempfile.TemporaryDirectory()
        self.addCleanup(td.cleanup)
        p = Path(td.name) / "research-dispositions.tsv"
        p.write_text(DISP_HEADER + "\nlll\tadopted\tkeep\n", encoding="utf-8")
        rows, _ = mod.read_tsv(p, DISP_HEADER.split("\t"))
        self.assertNotIn("date", rows[0])


@unittest.skip("strict reader not implemented yet; spec: "
               "docs/design/strict-reader-spec.md - unskip in the "
               "implementing slice (read_tsv -> (rows, truncated, counters))")
class StrictContract(unittest.TestCase):
    """The spec contract: skip-and-count, counters, fatal boundary."""

    def _write(self, name, data):
        td = tempfile.TemporaryDirectory()
        self.addCleanup(td.cleanup)
        p = Path(td.name) / name
        p.write_bytes(data if isinstance(data, bytes) else data.encode("utf-8"))
        return p

    def test_overwide_row_skipped_and_counted(self):
        p = self._write("l.tsv", GOOD_LINES_ROW + "\n"
                        + "bbb\treviewed\t2026-09-02T00:00:00Z\tt\textra\n"
                        + "ccc\texpanding\t2026-09-03T00:00:00Z\ttitle C\n")
        rows, truncated, c = mod.read_tsv(p, None)
        self.assertEqual(len(rows), 2)
        self.assertFalse(truncated)
        self.assertEqual(c["skipped_field_count"], 1)
        self.assertEqual(c["skipped_total"], 1)
        self.assertEqual(c["kept"], 2)
        self.assertEqual(c["first_skipped"], [{"line": 2, "category": "field-count"}])

    def test_underwide_row_skipped_and_counted(self):
        p = self._write("l.tsv", "bbb\treviewed\t2026-09-02T00:00:00Z\n")
        rows, truncated, c = mod.read_tsv(p, None)
        self.assertEqual(rows, [])
        self.assertEqual(c["skipped_field_count"], 1)

    def test_dispositions_legacy_rows_padded_and_counted(self):
        p = self._write("d.tsv", DISP_HEADER + "\n"
                        + "lll\tadopted\tkeep\trev\t/e\t2026-09-02\n")
        rows, truncated, c = mod.read_tsv(p, DISP_HEADER.split("\t"))
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]["followons"], "")  # padded, not skipped
        self.assertEqual(c["padded_legacy"], 1)
        self.assertEqual(c["skipped_total"], 0)

    def test_dispositions_under3_and_over9_skipped(self):
        p = self._write("d.tsv", DISP_HEADER + "\n"
                        + "m1\tadopted\n"
                        + "mmm\tkilled\tk\trev\t/e\t2026-09-02\ts\to\tf\tTENTH\n")
        rows, truncated, c = mod.read_tsv(p, DISP_HEADER.split("\t"))
        self.assertEqual(rows, [])
        self.assertEqual(c["skipped_field_count"], 2)

    def test_cr_row_skipped_not_stripped(self):
        # newline translation disabled: CRLF writers surface as cr
        # counters, not silent luck
        p = self._write("l.tsv", GOOD_LINES_ROW + "\r\n"
                        + "bbb\treviewed\t2026-09-02T00:00:00Z\tB\n")
        rows, truncated, c = mod.read_tsv(p, None)
        self.assertEqual([r["line"] for r in rows], ["bbb"])
        self.assertEqual(c["skipped_cr"], 1)

    def test_nul_row_skipped(self):
        p = self._write("l.tsv", b"bbb\tcontracting\t2026-09-04T00:00:00Z\tti\x00tle\n")
        rows, truncated, c = mod.read_tsv(p, None)
        self.assertEqual(rows, [])
        self.assertEqual(c["skipped_nul"], 1)

    def test_blank_and_comment_counted(self):
        p = self._write("l.tsv", "\n# note\n" + GOOD_LINES_ROW + "\n")
        rows, truncated, c = mod.read_tsv(p, None)
        self.assertEqual(len(rows), 1)
        self.assertEqual(c["skipped_blank"], 1)
        self.assertEqual(c["skipped_comment"], 1)

    def test_undecodable_row_skipped(self):
        p = self._write("l.tsv", b"bbb\treviewed\t2026-09-02T00:00:00Z\t\xff\xfe\n"
                        + GOOD_LINES_ROW.encode() + b"\n")
        rows, truncated, c = mod.read_tsv(p, None)
        self.assertEqual(len(rows), 1)
        self.assertEqual(c["skipped_undecodable"], 1)

    def test_counters_invariant(self):
        p = self._write("l.tsv", "\n# c\n" + GOOD_LINES_ROW + "\n"
                        + "bad\trow\n" + GOOD_LINES_ROW + "\r\n"
                        + "n\x00ul\trow\t2026-09-01T00:00:00Z\tt\n")
        rows, truncated, c = mod.read_tsv(p, None)
        self.assertEqual(c["raw_lines"], 6)
        self.assertEqual(c["kept"], 1)
        self.assertEqual(
            c["raw_lines"],
            c["header"] + c["kept"] + c["padded_legacy"]
            + c["skipped_total"] + c["cap_dropped"])

    def test_malformed_rows_never_consume_cap(self):
        body = "".join("row%03d\tplanned\t2026-09-01T00:00:00Z\tt%d\n" % (i, i)
                       for i in range(1, mod.ROW_CAP + 6))
        p = self._write("l.tsv", "bad\trow\n" + body)
        rows, truncated, c = mod.read_tsv(p, None)
        self.assertTrue(truncated)
        self.assertEqual(len(rows), mod.ROW_CAP)
        self.assertEqual(rows[0]["line"], "row006")  # oldest usable dropped
        self.assertEqual(c["skipped_field_count"], 1)
        self.assertEqual(c["cap_dropped"], 5)

    def test_stderr_logging_bounded(self):
        p = self._write("l.tsv", "\n".join(["bad\trow"] * 12) + "\n")
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            mod.read_tsv(p, None)
        text = err.getvalue()
        self.assertIn("research-lines.tsv:", text)
        self.assertIn("skipped field-count", text)
        self.assertIn("12 rows skipped", text)
        self.assertLessEqual(text.count("skipped field-count"), 11)  # 10 + summary

    def test_all_malformed_feed_is_fatal(self):
        old = mod.AUTOMATION_ROOT
        td = tempfile.TemporaryDirectory()
        self.addCleanup(td.cleanup)
        try:
            mod.AUTOMATION_ROOT = Path(td.name)
            (Path(td.name) / "research-lines.tsv").write_text("bad\trow\n")
            (Path(td.name) / "research-dispositions.tsv").write_text(
                DISP_HEADER + "\n")
            import json
            req = {"jsonrpc": "2.0", "id": 1, "method": "tools/call",
                   "params": {"name": "research_lines", "arguments": {}}}
            resp = mod.handle_request(req)
            self.assertTrue(resp["result"]["isError"])
        finally:
            mod.AUTOMATION_ROOT = old

    def test_header_drift_is_fatal(self):
        old = mod.AUTOMATION_ROOT
        td = tempfile.TemporaryDirectory()
        self.addCleanup(td.cleanup)
        try:
            mod.AUTOMATION_ROOT = Path(td.name)
            (Path(td.name) / "research-lines.tsv").write_text(
                GOOD_LINES_ROW + "\n")
            (Path(td.name) / "research-dispositions.tsv").write_text(
                "line\taction\tverdict\n")
            resp = mod.handle_request({"jsonrpc": "2.0", "id": 1,
                                       "method": "tools/call",
                                       "params": {"name": "research_lines",
                                                  "arguments": {}}})
            self.assertTrue(resp["result"]["isError"])
        finally:
            mod.AUTOMATION_ROOT = old

    def test_tool_result_carries_counters(self):
        old = mod.AUTOMATION_ROOT
        td = tempfile.TemporaryDirectory()
        self.addCleanup(td.cleanup)
        try:
            mod.AUTOMATION_ROOT = Path(td.name)
            (Path(td.name) / "research-lines.tsv").write_text(
                GOOD_LINES_ROW + "\n" + "bad\trow\n")
            (Path(td.name) / "research-dispositions.tsv").write_text(
                DISP_HEADER + "\n"
                + "aaa\tadopted\tkeep\trev\t/e\t2026-09-02\n")
            result = mod.tool_research_lines({})
            self.assertIn("counters", result)
            self.assertEqual(result["counters"]["lines"]["skipped_total"], 1)
            self.assertEqual(result["counts"]["lines"], 1)
        finally:
            mod.AUTOMATION_ROOT = old


if __name__ == "__main__":
    unittest.main()