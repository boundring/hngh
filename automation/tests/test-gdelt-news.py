#!/usr/bin/env python3
"""gdelt-news lane, hermetic.

Exercises jobs/gdelt-news.py against a hand-built fixture export zip
(known rows: lanes, scores, duplicate URLs, malformed lines) plus a
dead lastupdate URL for the fail-closed path. No network beyond a
refused localhost port; no real digest/state touched.
"""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
import unittest.mock
import zipfile
from pathlib import Path
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parent.parent  # automation/


def _load(name, rel):
    spec = importlib.util.spec_from_file_location(name, str(ROOT / rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


gn = _load("gdelt_news", "jobs/gdelt-news.py")


def _row(gid, ts, root, base, quad, gold, ns, tone, a1, a2, url):
    f = [""] * 61
    f[0], f[1], f[28], f[27], f[29] = gid, ts.replace("-", ""), root, base, quad
    f[30], f[32], f[34] = str(gold), str(ns), str(tone)
    f[6], f[16] = a1, a2
    f[59], f[60] = ts, url
    return "\t".join(f)


TS = "2026-09-12T040000"
FIXTURE_ROWS = [
    # big conflict story: ns=10, g=-10 -> score 120 -> CRITICAL
    _row("1", TS, "19", "190", "4", -10.0, 10, -4.0, "RUSSIA", "UKRAINE",
         "https://example.test/war-escalates-in-region"),
    # same URL again with fewer sources: dedup keeps the max row
    _row("2", TS, "19", "190", "4", -4.0, 3, -2.0, "RUSSIA", "UKRAINE",
         "https://example.test/war-escalates-in-region"),
    # moderate conflict: ns=3, g=-4 -> score 18 -> CONTEXT
    _row("3", TS, "14", "140", "3", -4.0, 3, -3.0, "FRANCE", "",
         "https://example.test/protest-march-in-paris"),
    # good lane: humanitarian aid, ns=6, tone=6 -> score 66 -> capped NOTABLE
    _row("4", TS, "07", "073", "2", 5.0, 6, 6.0, "UN", "SUDAN",
         "https://example.test/un-delivers-aid-convoy"),
    # good lane chit-chat: ns=1, tone=1 -> score 6 -> CONTEXT
    _row("5", TS, "05", "051", "1", 2.0, 1, 1.0, "CANADA", "",
         "https://example.test/envoy-praises-talks"),
    # not in lens: neutral verbal cooperation, quad 1, tone 0.2 -> skip
    _row("6", TS, "01", "010", "1", 1.0, 9, 0.2, "JAPAN", "CHINA",
         "https://example.test/ministers-meet-in-tokyo"),
    "malformed-garbage-line",
    _row("7", TS, "19", "190", "4", "not-a-number", 5, 0, "X", "Y",
         "https://example.test/bad-row"),
]


def _fixture_zip(path):
    inner = "20260912040000.export.CSV"
    with zipfile.ZipFile(path, "w") as z:
        z.writestr(inner, "\n".join(FIXTURE_ROWS) + "\n")


class TestRank(unittest.TestCase):
    def test_lane_scores_and_dedup(self):
        items = gn.rank_rows("\n".join(FIXTURE_ROWS), "0400")
        by_url = {i["url"]: i for i in items}
        self.assertEqual(len(by_url), 4)  # dup URL + 3 non-lens/bad rows
        war = by_url["https://example.test/war-escalates-in-region"]
        self.assertEqual(war["lane"], "world")
        self.assertEqual(war["score"], 120.0)  # ns=10 x (|-10|+2)
        aid = by_url["https://example.test/un-delivers-aid-convoy"]
        self.assertEqual(aid["lane"], "good")
        self.assertEqual(aid["score"], 66.0)  # ns=6 x (6+5)

    def test_bands_and_block_shape(self):
        with unittest.mock.patch.dict(os.environ,
                                      {}):
            items = gn.rank_rows("\n".join(FIXTURE_ROWS), "0400")
            block = gn.render_block(items, "0400", "2026-09-12")
        lines = block.splitlines()
        self.assertEqual(lines[0], "## 0400 2026-09-12")
        self.assertTrue(lines[1].startswith("_sources: gdelt | model: "))
        self.assertTrue(lines[1].endswith("_"))
        tags = [l.split(":")[0] for l in lines[2:] if l.strip()]
        self.assertIn("CRITICAL", tags)
        # good lane never CRITICAL
        for l in lines[2:]:
            if "[aid]" in l or "PROVIDE-AID" in l:
                self.assertFalse(l.startswith("CRITICAL: "))

    def test_block_scrubs_path_tokens(self):
        # digest writer guard (mega-block census 2026-09-16): the block
        # is deck A on the dashboard/email/newspaper chain; actor tokens
        # come from wire data, but any host path that ever transits an
        # item field must not survive the render
        rows = list(FIXTURE_ROWS)
        pathy = _row("8", TS, "19", "190", "4", -10.0, 10, -4.0,
                     "/home/aubergine", "~/dots/vimrc",
                     "https://example.test/pathy-actors-story")
        rows.append(pathy)
        items = gn.rank_rows("\n".join(rows), "0400")
        block = gn.render_block(items, "0400", "2026-09-12")
        for token in ("/home/aubergine", "~/dots", "/tmp/hngh"):
            self.assertNotIn(token, block)
        self.assertIn("pathy-actors-story", block)  # kept, redacted


class TestCli(unittest.TestCase):
    def _run(self, tmp, export=None, lastupdate=None):
        cmd = [sys.executable, "-B", str(ROOT / "jobs/gdelt-news.py"),
               "2026-09-12", "--digest", str(tmp / "digest"),
               "--state", str(tmp / "seen.tsv")]
        if export:
            cmd += ["--export", str(export)]
        env = dict(gn.os.environ,
                   GDELT_LASTUPDATE_URL="http://127.0.0.1:1/lastupdate.txt",
                   HNGH_CRUMBS_DB=str(tmp / "crumbs.db"),
                   )
        return subprocess.run(cmd, capture_output=True, text=True,
                              timeout=60, env=env)

    def test_block_written_and_deduped(self):
        with tempfile.TemporaryDirectory() as d:
            tmp = Path(d)
            (tmp / "digest").mkdir()
            z = tmp / "export.zip"
            _fixture_zip(z)
            r = self._run(tmp, export=z)
            self.assertEqual(r.returncode, 0, r.stderr)
            digest = (tmp / "digest" / "2026-09-12.md").read_text()
            self.assertIn("## 0400 2026-09-12", digest)
            self.assertIn("(https://example.test/war-escalates-in-region)", digest)
            # second run: same URLs are already in the state file -> no block
            r2 = self._run(tmp, export=z)
            self.assertEqual(r2.returncode, 0, r2.stderr)
            self.assertEqual(
                digest, (tmp / "digest" / "2026-09-12.md").read_text())

    def test_dead_lastupdate_fails_closed(self):
        with tempfile.TemporaryDirectory() as d:
            tmp = Path(d)
            (tmp / "digest").mkdir()
            r = self._run(tmp)
            self.assertEqual(r.returncode, 0, r.stderr)
            files = list((tmp / "digest").iterdir())
            self.assertEqual(files, [])


class TestNumSourcesWindow(unittest.TestCase):
    def test_window_boundary_filters_old_records(self):
        now, day = 100000.0, 86400.0
        recs = [(now - day, 4),      # exactly at the 24h boundary: in
                (now - day - 1, 3),  # one second older: out
                (now - 3600, 10)]    # recent: in
        self.assertEqual(gn.num_sources_window(recs, 24, now=now), 14)

    def test_scalar_timestamps_count_one_source(self):
        self.assertEqual(gn.num_sources_window([1, 2, 3], 1), 3)

    def test_malformed_and_empty_fail_closed(self):
        self.assertEqual(gn.num_sources_window([], 24), 0)
        self.assertEqual(
            gn.num_sources_window([("bad", 5), (50, "x"), (59, 2)],
                                  1, now=60), 2)


class TestNs24Aggregation(unittest.TestCase):
    def test_history_and_aggregate_from_snapshots(self):
        with tempfile.TemporaryDirectory() as d:
            snap = Path(d)
            (snap / "gdelt-0300.json").write_text(json.dumps(
                {"date": "2026-09-12", "window": "0300",
                 "items": [{"url": "https://example.test/story",
                            "num_sources": 6}]}))
            now = datetime(2026, 9, 12, 14, 30,
                           tzinfo=timezone.utc).timestamp()
            hist = gn.story_history(str(snap), now)
            self.assertEqual(
                hist["https://example.test/story"],
                [(datetime(2026, 9, 12, 3, 0,
                           tzinfo=timezone.utc).timestamp(), 6)])
            item = {"url": "https://example.test/story", "num_sources": 4}
            gn.attach_ns24([item], hist, now)
            self.assertEqual(item["ns24"], 10)
            hist["https://example.test/stale"] = [(now - 90000, 100)]
            stale = {"url": "https://example.test/stale",
                     "num_sources": 4}
            gn.attach_ns24([stale], hist, now)
            self.assertEqual(stale["ns24"], 4)  # stale record filtered

    def test_rank_rows_retains_num_sources(self):
        items = gn.rank_rows("\n".join(FIXTURE_ROWS), "0400")
        by_url = {i["url"]: i for i in items}
        self.assertEqual(
            by_url["https://example.test/war-escalates-in-region"]
            ["num_sources"], 10)


class CrumbSeam(unittest.TestCase):
    """P1 seam closure: the writer's breadcrumb rides the single
    journal seam (lib/crumbs.py) - one 4-field line, writer stamp,
    scrub escaping (| -> \u00a6), never a rolled-own append."""

    def test_breadcrumb_writes_one_stamped_line(self):
        with tempfile.TemporaryDirectory() as td:
            db = os.path.join(td, "crumbs.db")
            os.environ["HNGH_CRUMBS_DB"] = db
            try:
                gn.breadcrumb("quiet", "pipe|here")
            finally:
                os.environ.pop("HNGH_CRUMBS_DB", None)
            lines = subprocess.run(
                ["python3", str(ROOT / "lib" / "crumbs-db.py"), "export",
                 "--db", db],
                capture_output=True, text=True, check=True,
            ).stdout.splitlines()
        self.assertEqual(len(lines), 1)
        self.assertRegex(
            lines[0],
            r"^[\d:TZ-]+ \| gdelt-news \| quiet \| pipe\u00a6here \[w=[^@\s]+@\d+\]$")


if __name__ == "__main__":
    unittest.main()
