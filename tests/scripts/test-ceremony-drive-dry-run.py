#!/usr/bin/env python3
"""ceremony-drive --dry-run: the rehearsal lane, test-backed.

A dream drive runs the closed loop -- create-run + admit-transport +
propose + issue-cert prepare-candidate -- against a fresh
/tmp/hngh-dream-<ts> store, then stops: no mutation-check at all (the
mutation executor would run the certificate-bound Git command on the
real repository), no commit certificate, no push leg. It prints a
report: per-step exit codes, the rendered verdict text, candidate
paths, content hash, and the exact commands the real drive would run.

Contract (hermetic: a disposable fixture repo, no network):
- exit 0 on a clean candidate, and the refusal exit path on a broken
  one (the report is a report; it changes no governance).
- no new commit, no staged index entry, no push in the test repo.
- no store or ledger writes outside the dream store directory.
"""

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = ROOT / "scripts" / "ceremony-drive"

# Fixture containment (2026-09-17): an exported GIT_DIR/GIT_WORK_TREE
# would silently redirect the fixture `git init`/`config`/`commit` below
# (and the drive's own subprocesses) into that repository instead of the
# disposable fixture. Strip repo-selection variables for the whole test
# process and pin global/system config to /dev/null so the fixture never
# depends on host git state.
for _HOSTILE_VAR in ("GIT_DIR", "GIT_WORK_TREE"):
  os.environ.pop(_HOSTILE_VAR, None)
for _CONFIG_VAR in ("GIT_CONFIG_GLOBAL", "GIT_CONFIG_SYSTEM"):
  os.environ.setdefault(_CONFIG_VAR, "/dev/null")


class DreamDrive(unittest.TestCase):
  def setUp(self):
    self._td = tempfile.TemporaryDirectory()
    self.fixture = Path(self._td.name)
    self._init_fixture_repo()

  def tearDown(self):
    self._td.cleanup()

  def _init_fixture_repo(self):
    """A fixture repo that can host a real candidate: a trivial gate
    (Makefile with a green test target) plus copies of the repo's
    candidate-verification scripts, which run relative to the drive's
    working directory."""
    subprocess.run(["git", "init", "-q", str(self.fixture)], check=True,
                   env=dict(os.environ))
    src = self.fixture / "docs" / "fixture.txt"
    src.parent.mkdir(parents=True)
    src.write_text("fixture candidate\n")
    makefile = self.fixture / "Makefile"
    makefile.write_text("test:\n\t@echo fixture mock gate green\n")
    scripts_dir = self.fixture / "scripts"
    scripts_dir.mkdir()
    for name in ("verify-candidate.py", "lint-parens.py"):
      shutil.copy(ROOT / "scripts" / name, scripts_dir / name)
    subprocess.run(["git", "-C", str(self.fixture), "add", "-A"],
                   check=True)
    # Identity is pinned at commit time; nothing is written into the
    # fixture's config (a stray config write can only pollute whichever
    # repo git resolves to).
    subprocess.run(["git", "-C", str(self.fixture),
                    "-c", "user.email=test@example.com",
                    "-c", "user.name=test@example.com",
                    "commit", "-qm", "fixture base"], check=True)
    self.candidate = "docs/fixture.txt"

  def run_dream(self, candidate=None, pre_save=None):
    """Run sbcl --script scripts/ceremony-drive --dry-run in the fixture
    repo. PRE_SAVE is called with the fixture Path before the run."""
    if pre_save:
      pre_save(self.fixture)
    out = subprocess.run(
      ["sbcl", "--script", str(SCRIPT), "--dry-run",
       "pre-validate dream step", candidate or self.candidate],
      capture_output=True, text=True, cwd=self.fixture, timeout=900)
    return out

  def head(self):
    return subprocess.run(
      ["git", "-C", str(self.fixture), "rev-parse", "HEAD"],
      capture_output=True, text=True, check=True).stdout.strip()

  def status(self):
    return subprocess.run(
      ["git", "-C", str(self.fixture), "status", "--porcelain"],
      capture_output=True, text=True, check=True).stdout

  def test_success_reports_and_stops_before_mutation(self):
    before = self.head()
    out = self.run_dream()
    self.assertEqual(out.returncode, 0, out.stdout + out.stderr)
    self.assertIn("[dream] create-run exit=0", out.stdout)
    self.assertIn("[dream] admit-transport exit=0", out.stdout)
    self.assertIn("[dream] propose exit=0", out.stdout)
    self.assertIn("[dream] issue-cert-prepare-candidate exit=0", out.stdout)
    self.assertIn("verdict state=admitted principles=10", out.stdout)
    self.assertIn(self.candidate, out.stdout)
    self.assertIn("mutation-check prepare-candidate run-1", out.stdout)
    self.assertIn("issue-cert commit run-1", out.stdout)
    self.assertIn("mutation-check commit run-1", out.stdout)
    # no real mutation: HEAD unchanged, nothing staged
    self.assertEqual(before, self.head())
    self.assertEqual(self.status(), "")

  def test_store_is_a_dream_store(self):
    out = self.run_dream()
    self.assertEqual(out.returncode, 0, out.stdout + out.stderr)
    stores = [line.split("store=", 1)[1].split()[0]
              for line in out.stdout.splitlines()
              if line.strip().startswith("[dream] store=")]
    self.assertTrue(stores, "no [dream] store= row in the report")
    for store in stores:
      self.assertTrue(store.startswith("/tmp/hngh-dream-"), store)

  def test_broken_candidate_refuses_cleanly(self):
    def break_candidate(root):
      (root / self.candidate).write_text("\x7f refuse bait\n")
    # bait first, snapshot the deliberately dirty status, then run the
    # dream drive on it: the refusal must add no repository change of
    # its own (the drive has no tree-mutating code path), so the
    # status is byte-identical before and after the run
    break_candidate(self.fixture)
    bait_status = self.status()
    self.assertTrue(bait_status, "bait write did not dirty the fixture")
    out = self.run_dream(pre_save=None)
    self.assertNotEqual(out.returncode, 0)
    self.assertIn("refus", (out.stdout + out.stderr).lower())
    self.assertEqual(self.status(), bait_status)

  def test_usage_without_dry_run_or_store(self):
    out = subprocess.run(
      ["sbcl", "--script", str(SCRIPT), "objective", "x.lisp"],
      capture_output=True, text=True, cwd=self.fixture, timeout=300)
    self.assertEqual(out.returncode, 2)
    self.assertIn("usage", out.stdout)


if __name__ == "__main__":
  unittest.main(verbosity=2)
