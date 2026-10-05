#!/usr/bin/env python3
"""dashboard-self-review heartbeat (2026-10-04).

Contract: every tick files the `[dash-selfreview] summary` row — findings
or not. The report-queue identity dedup bumps one row xN within
REPORT_WINDOW, so the ledger carries a live heartbeat without churn, and
the dashboard client cuts resolved alert history at the newest
"summary: 0 findings" row (jobs/dashboard-self-review.py main +
dashboard/app.js selfReviewAlerts).

Hermetic: fixture repo root with the REAL scripts/report-queue copied in;
HNGH_REPO + HNGH_REPORT_ROOT point there; no live ledger touched.
"""

import os
import shutil
import tempfile
import time
import unittest
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JOB = ROOT / "jobs" / "dashboard-self-review.py"
RQ = ROOT.parent / "scripts" / "report-queue"


def make_repo():
    k = Path(tempfile.mkdtemp(prefix="hngh-selfreview-heartbeat-"))
    (k / "scripts").mkdir()
    (k / "docs" / "project" / "report-bodies").mkdir(parents=True)
    shutil.copy2(RQ, k / "scripts" / "report-queue")
    return k


def load_job(repo):
    saved = {k: os.environ.get(k) for k in ("HNGH_REPO", "HNGH_REPORT_ROOT")}
    os.environ["HNGH_REPO"] = str(repo)
    os.environ["HNGH_REPORT_ROOT"] = str(repo)
    try:
        loader = SourceFileLoader(
            f"dashboard_self_review_{time.time_ns()}", str(JOB))
        spec = spec_from_loader(loader.name, loader)
        mod = module_from_spec(spec)
        loader.exec_module(mod)
        return mod
    finally:
        for k, v in saved.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v


def summaries(repo):
    p = repo / "docs" / "project" / "reports.md"
    if not p.exists():
        return []
    return [l for l in p.read_text().splitlines()
            if "dash-selfreview] summary" in l]


class Heartbeat(unittest.TestCase):
    def test_all_clear_files_and_bumps_one_summary_row(self):
        repo = make_repo()
        mod = load_job(repo)
        mod.report([])
        mod.report([])
        rows = summaries(repo)
        self.assertEqual(len(rows), 1, rows)
        self.assertIn("[dash-selfreview] summary: 0 findings "
                      "(0 unacceptable-now, 0 acceptable-for-now)", rows[0])
        self.assertIn("×2", rows[0], rows[0])  # second tick bumped, not added

    def test_findings_rows_and_summary_coexist(self):
        repo = make_repo()
        mod = load_job(repo)
        mod.report([mod.finding("feed-fresh:x.json", True, "stale 99s")])
        rows = summaries(repo)
        self.assertEqual(len(rows), 1, rows)
        self.assertIn("1 findings (1 unacceptable-now", rows[0])
        ledger = (repo / "docs" / "project" / "reports.md").read_text()
        self.assertIn("feed-fresh:x.json: unacceptable-now", ledger)

    def test_state_change_refiles_not_bumps(self):
        # 3-findings row then a clean tick: the heartbeat must NOT bump the
        # stale "1 findings" row (bump keeps its text alive forever); it
        # files a fresh "0 findings" row and the old one ages out.
        repo = make_repo()
        mod = load_job(repo)
        mod.report([mod.finding("feed-fresh:x.json", True, "stale 99s")])
        mod.report([])
        rows = summaries(repo)
        self.assertEqual(len(rows), 2, rows)
        self.assertIn("1 findings (1 unacceptable-now", rows[0])
        self.assertIn("0 findings (0 unacceptable-now", rows[1])
        self.assertNotIn("\u00d7", rows[1])

    def test_recovery_then_realert_cuts_correctly(self):
        # client-side contract rehearsal: rows after the newest clean
        # summary alert; rows before it are resolved history.
        rows = [
            {"first": "[dash-selfreview] feed-fresh:x.json: "
                      "unacceptable-now — stale 99s"},
            {"first": "[dash-selfreview] summary: 2 findings "
                      "(2 unacceptable-now, 0 acceptable-for-now)"},
            {"first": "[dash-selfreview] summary: 0 findings "
                      "(0 unacceptable-now, 0 acceptable-for-now)"},
            {"first": "[dash-selfreview] slow-unit:y: failing 1 checks"},
        ]
        cut = -1
        for i, r in enumerate(rows):
            if "summary: 0 findings" in (r["first"] or ""):
                cut = i
        alerts = [r for r in rows[cut + 1:]
                  if "[dash-selfreview]" in (r["first"] or "")
                  and __import__("re").search(
                      r"unacceptable|stale|missing|failing", r["first"])]
        self.assertEqual(len(alerts), 1)
        self.assertIn("slow-unit:y", alerts[0]["first"])


if __name__ == "__main__":
    unittest.main()
