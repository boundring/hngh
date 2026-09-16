#!/usr/bin/env python3
"""Tests for jobs/hygiene.py (test-first, hermetic).

Env overrides used:
  HNGH_REPORT_ROOT        report-queue repo-root override (existing contract)
  HYGIENE_REPO_ROOT       repo scan root for hygiene.py
  HYGIENE_JCODE_HOME      fake ~/.jcode root for hygiene.py
  HYGIENE_HANDOFF_FILE    fake automation/agent-handoffs.md
  HYGIENE_NO_HANDOFF=1    skip the ambient memory append entirely
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
JOB = os.path.join(HERE, "..", "jobs", "hygiene.py")
DEAD_PID = 4194301  # above pid_max on default Linux (4194304 cap)


def run_job(env, *args):
    e = dict(os.environ)
    e.update(env)
    return subprocess.run(
        [sys.executable, JOB, *args], env=e,
        capture_output=True, text=True, timeout=60)


def make_session(root, name, status, age_s):
    d = os.path.join(root, "sessions")
    os.makedirs(d, exist_ok=True)
    p = os.path.join(d, name)
    with open(p, "w") as f:
        f.write(json.dumps({"status": status, "session_id": name}))
    old = time.time() - age_s
    os.utime(p, (old, old))
    return p


class HygieneTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="hyg-test-")
        self.jcode = os.path.join(self.tmp, "jcode-home", ".jcode")
        self.repo = os.path.join(self.tmp, "repo")
        self.report_root = os.path.join(self.tmp, "report-root")
        self.handoff = os.path.join(self.tmp, "agent-handoffs.md")
        for d in (self.jcode, self.repo, self.report_root):
            os.makedirs(d)
        with open(self.handoff, "w") as f:
            f.write("actor | ts | scope|id | body\n")
        self.env = {
            "HYGIENE_JCODE_HOME": self.jcode,
            "HYGIENE_REPO_ROOT": self.repo,
            "HNGH_REPORT_ROOT": self.report_root,
            "HYGIENE_HANDOFF_FILE": self.handoff,
        }

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def report_rows(self):
        docs = os.path.join(self.report_root, "docs", "project")
        rows = os.path.join(docs, "reports.md")
        if not os.path.exists(rows):
            return ""
        with open(rows) as f:
            return f.read()

    def test_00_clean_run_is_quiet_and_exit0(self):
        r = run_job(self.env, "--json")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(self.report_rows(), "", "no rows when clean")
        self.assertIn('"zombie_sessions": 0', r.stdout)

    def test_01_zombie_active_sessions_found(self):
        make_session(self.jcode, "session_z1.json", "Active", 48 * 3600)
        make_session(self.jcode, "session_fresh.json", "Active", 60)
        make_session(self.jcode, "session_done.json", "Completed", 48 * 3600)
        r = run_job(self.env, "--json")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('"zombie_sessions": 1', r.stdout)
        self.assertIn("zombie Active session", self.report_rows())

    def test_02_dead_pidfile_report_and_fix(self):
        pd = os.path.join(self.jcode, "active_pids")
        os.makedirs(pd)
        dead = os.path.join(pd, "%d.pid" % DEAD_PID)
        with open(dead, "w") as f:
            f.write(str(DEAD_PID))
        r = run_job(self.env, "--json")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('"dead_pidfiles": 1', r.stdout)
        self.assertTrue(os.path.exists(dead), "report-only: no delete")
        r = run_job(self.env, "--fix", "--json")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(os.path.exists(dead), "--fix removes dead pidfile")

    def test_03_stray_root_file_reported(self):
        with open(os.path.join(self.repo, "--model"), "w") as f:
            f.write("x")
        r = run_job(self.env, "--json")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('"stray_root_files": 1', r.stdout)
        rows = self.report_rows()
        self.assertIn("stray root file", rows)

    def test_04_empty_scratch_dirs_aged(self):
        d = os.path.join(self.repo, ".agent-scratch", "old1")
        os.makedirs(d)
        w = os.path.join(self.repo, ".scratch", "work-old")
        os.makedirs(w)
        with open(os.path.join(w, "state.md"), "w") as f:
            f.write("work")
        old = time.time() - 8 * 86400
        os.utime(d, (old, old))
        os.utime(w, (old, old))
        r = run_job(self.env, "--json")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('"empty_scratch_dirs": 1', r.stdout)
        self.assertIn('"aged_work_dirs": 1', r.stdout)

    def test_05_handoff_line_appended(self):
        make_session(self.jcode, "session_z1.json", "Active", 48 * 3600)
        run_job(self.env, "--json")
        with open(self.handoff) as f:
            lines = f.read().strip().splitlines()
        self.assertEqual(len(lines), 2)
        self.assertTrue(lines[1].startswith("hygiene | "))

    def test_06_never_exits_nonzero_on_missing_roots(self):
        env = dict(self.env)
        env["HYGIENE_JCODE_HOME"] = os.path.join(self.tmp, "nope1")
        env["HYGIENE_REPO_ROOT"] = os.path.join(self.tmp, "nope2")
        r = run_job(env, "--json")
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_07_report_root_never_falls_back_to_cwd(self):
        """With no HNGH_REPORT_ROOT, rows land in the KERNEL repo.

        The 2026-09-16 second-ledger incident: report_root() fell back to
        os.getcwd(), and under cadence-tick the cwd is the automation
        checkout, silently forking a second ledger at
        automation/docs/project/ that the kernel dashboard never reads.
        The kernel root is structural (parent of automation/). Hermetic:
        the job is copied into a sandbox tree, so the structural
        derivation resolves inside the sandbox, never the real repo.
        """
        sandbox_auto = os.path.join(self.tmp, "sandbox", "automation")
        os.makedirs(os.path.join(sandbox_auto, "jobs"))
        job_copy = os.path.join(sandbox_auto, "jobs", "hygiene.py")
        shutil.copy(JOB, job_copy)
        # the kernel-root contract includes scripts/report-queue (hygiene
        # invokes it from the derived kernel root): replicate that layout
        real_root = os.path.dirname(os.path.dirname(HERE))
        sandbox_scripts = os.path.join(os.path.dirname(sandbox_auto),
                                       "scripts")
        os.makedirs(sandbox_scripts)
        shutil.copy(os.path.join(real_root, "scripts", "report-queue"),
                    os.path.join(sandbox_scripts, "report-queue"))
        make_session(self.jcode, "session_z1.json", "Active", 48 * 3600)
        env = dict(self.env)
        del env["HNGH_REPORT_ROOT"]
        env["HYGIENE_REPO_ROOT"] = self.repo
        # misleading cwd: a directory that is NOT any report root
        r = subprocess.run(
            [sys.executable, job_copy, "--json"], env=env, cwd=self.tmp,
            capture_output=True, text=True, timeout=60)
        self.assertEqual(r.returncode, 0, r.stderr)
        sandbox_docs = os.path.join(os.path.dirname(sandbox_auto),
                                    "docs", "project")
        with open(os.path.join(sandbox_docs, "reports.md")) as f:
            kernel_rows = f.read()
        self.assertIn("zombie Active session", kernel_rows)
        # nothing was written under the misleading cwd
        self.assertFalse(
            os.path.exists(os.path.join(self.tmp, "docs", "project",
                                        "reports.md")),
            "cwd must never become a report root")


if __name__ == "__main__":
    unittest.main(verbosity=2)
