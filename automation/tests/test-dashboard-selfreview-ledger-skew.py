#!/usr/bin/env python3
"""Skew-aware ledger-sanity check (plan 2026-09-12-routed-dash-selfreview-ledger-sync-skew).

The ledger-sanity check in jobs/dashboard-self-review.py compares the
report-queue --json row count against the report-bodies glob count.
Cross-machine ledger-sync skew makes that delta flap (25 -> 1761-1811)
with zero local corruption, so a count past LEDGER_DRIFT_MAX is an
emergency only when the local tree has had a fair chance to sync.

Contract (docs/research/2026-09-12-dash-selfreview-ledger-sync-skew.md):
  fresh tree (HEAD age <= LEDGER_SKEW_MAX_AGE) + drift > LEDGER_DRIFT_MAX
      -> unacceptable-now "stale skew — reconcile"
  stale tree (HEAD age > LEDGER_SKEW_MAX_AGE) + drift > LEDGER_DRIFT_MAX
      -> acceptable-for-now transient cross-machine sync skew
  fresh tree + drift within threshold -> silent
  unmeasurable HEAD age + drift -> unacceptable-now (fail closed:
  only an explained, windowed transient is downgraded, never an
  unknown one)

Hermetic: temp fixture kernel repo (fake report-queue, report-bodies,
real git with a controlled HEAD commit date); no network, no secrets,
no live ledger touched.
"""

import os
import shutil
import subprocess
import tempfile
import time
import unittest
from importlib.machinery import SourceFileLoader
from importlib.util import module_from_spec, spec_from_loader
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JOB = ROOT / "jobs" / "dashboard-self-review.py"


def load_job(env_overrides):
    """Load dashboard-self-review.py fresh with HNGH_REPO pointed at a fixture."""
    saved = {k: os.environ.get(k)
             for k in ("HNGH_REPO", "LEDGER_SKEW_MAX_AGE", "LEDGER_DRIFT_MAX")}
    os.environ.update(env_overrides)
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


def make_kernel(rows, bodies, head_age=None):
    """Fixture kernel repo: fake report-queue printing `rows` reports,
    `bodies` body files, and (optionally) a git HEAD dated head_age s ago."""
    k = Path(tempfile.mkdtemp(prefix="hngh-ledger-skew-"))
    (k / "scripts").mkdir(parents=True)
    (k / "docs" / "project" / "report-bodies").mkdir(parents=True)
    rq = k / "scripts" / "report-queue"
    rq.write_text(
        "#!/usr/bin/env python3\n"
        "import json\n"
        f"print(json.dumps({{'reports': [{{}}] * {rows}, "
        f"'summary': {{'alert': {rows}}}}}))\n")
    rq.chmod(0o755)
    for i in range(bodies):
        (k / "docs" / "project" / "report-bodies" / f"r{i}.md").write_text("x\n")
    if head_age is not None:
        when = f"@{int(time.time()) - head_age} +0000"
        env = dict(os.environ, GIT_AUTHOR_DATE=when, GIT_COMMITTER_DATE=when)
        for hostile in ("GIT_DIR", "GIT_WORK_TREE"):
            env.pop(hostile, None)
        subprocess.run(["git", "init", "-q", str(k)], check=True, env=env)
        subprocess.run(
            ["git", "-C", str(k), "-c", "user.email=t@t", "-c", "user.name=t",
             "commit", "--allow-empty", "-q", "-m", "fixture"],
            check=True, env=env, capture_output=True)
    return k


class LedgerSkew(unittest.TestCase):
    def setUp(self):
        self._tmpdirs = []

    def tearDown(self):
        for d in self._tmpdirs:
            shutil.rmtree(d, ignore_errors=True)

    def _run(self, rows, bodies, head_age=None, skew_age=None):
        k = make_kernel(rows, bodies, head_age)
        self._tmpdirs.append(k)
        env = {"HNGH_REPO": str(k)}
        if skew_age is not None:
            env["LEDGER_SKEW_MAX_AGE"] = str(skew_age)
        return load_job(env).check_ledger()

    def test_fresh_tree_drift_is_unacceptable_now(self):
        f = self._run(rows=100, bodies=10, head_age=60)
        self.assertEqual(len(f), 1)
        self.assertEqual(f[0]["status"], "unacceptable-now")
        self.assertIn("stale skew — reconcile", f[0]["detail"])

    def test_stale_tree_drift_is_transient(self):
        f = self._run(rows=100, bodies=10, head_age=100000)
        self.assertEqual(len(f), 1)
        self.assertEqual(f[0]["status"], "acceptable-for-now")
        self.assertIn("transient cross-machine sync skew", f[0]["detail"])

    def test_fresh_tree_clean_is_silent(self):
        f = self._run(rows=60, bodies=50, head_age=60)
        self.assertEqual(f, [])

    def test_unmeasurable_age_fails_closed(self):
        # no .git in the fixture -> HEAD age unmeasurable -> drift stays
        # unacceptable-now (never downgrade an unknown).
        f = self._run(rows=100, bodies=10, head_age=None)
        self.assertEqual(len(f), 1)
        self.assertEqual(f[0]["status"], "unacceptable-now")

    def test_default_skew_window_is_7200s(self):
        k = make_kernel(0, 0)
        self._tmpdirs.append(k)
        mod = load_job({"HNGH_REPO": str(k)})
        self.assertEqual(mod.LEDGER_SKEW_MAX_AGE, 7200)

    def test_unread_only_json_reports_not_drift_counted(self):
        # --json's `reports` is the unread-only subset (new rows past
        # the cursor); the drift comparison must use total ledger rows
        # (the kinds in `summary` sum to read_rows total). The real
        # fleet read 237 unread rows against 3004 body files and called
        # it a 2767-row emergency.
        f = self._rows_fixture(unread=10, total=80, bodies=80, head_age=60)
        self.assertEqual(f, [])

    def _rows_fixture(self, unread, total, bodies, head_age=None):
        k = Path(tempfile.mkdtemp(prefix="hngh-ledger-skew-"))
        self._tmpdirs.append(k)
        (k / "scripts").mkdir(parents=True)
        (k / "docs" / "project" / "report-bodies").mkdir(parents=True)
        rq = k / "scripts" / "report-queue"
        rq.write_text(
            "#!/usr/bin/env python3\n"
            "import json\n"
            f"print(json.dumps({{'reports': [{{}}] * {unread}, "
            f"'summary': {{'alert': {total}}}}}))\n")
        rq.chmod(0o755)
        for i in range(bodies):
            (k / "docs" / "project" / "report-bodies" / f"r{i}.md").write_text("x\n")
        if head_age is not None:
            when = f"@{int(time.time()) - head_age} +0000"
            env = dict(os.environ, GIT_AUTHOR_DATE=when, GIT_COMMITTER_DATE=when)
            for hostile in ("GIT_DIR", "GIT_WORK_TREE"):
                env.pop(hostile, None)
            subprocess.run(["git", "init", "-q", str(k)], check=True, env=env)
            subprocess.run(
                ["git", "-C", str(k), "-c", "user.email=t@t", "-c", "user.name=t",
                 "commit", "--allow-empty", "-q", "-m", "fixture"],
                check=True, env=env, capture_output=True)
        return load_job({"HNGH_REPO": str(k)}).check_ledger()


if __name__ == "__main__":
    unittest.main()
