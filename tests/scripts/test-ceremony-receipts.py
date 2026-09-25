#!/usr/bin/env python3
"""ceremony-drive --fast-lane + cert receipts: mechanical commit lane.

The fast lane (refoundation P5c) admits one narrow candidate class --
a whitespace-only working-tree diff whose verify-candidate run is
clean -- through the same certificate verb as a full drive
(mutation-check commit), with a mechanical verdict report and zero
model review round-trips. Every successful mutation-check mint also
appends a receipt row (P5a): ts|content-hash|action|expiry under
HNGH_RECEIPTS_PATH, mirroring the kernel's +86400s certificate TTL.

Contract (hermetic: disposable fixture repo, no network):
- a substantive (non-whitespace) candidate refuses: exit 2, no commit,
  no receipt row.
- a whitespace-only candidate on a green fixture commits exactly one
  "hngh: candidate <hash>" commit and appends one action=commit
  receipt row carrying the same content hash.
- --fast-lane without --store refuses with usage (exit 2).
- the receipts CLI appends and cats the same 4-field rows.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = ROOT / "scripts" / "ceremony-drive"
RECEIPTS_CLI = ROOT / "scripts" / "cert-receipts.lisp"

for _HOSTILE_VAR in ("GIT_DIR", "GIT_WORK_TREE"):
  os.environ.pop(_HOSTILE_VAR, None)
for _CONFIG_VAR in ("GIT_CONFIG_GLOBAL", "GIT_CONFIG_SYSTEM"):
  os.environ.setdefault(_CONFIG_VAR, "/dev/null")


class FastLaneReceipts(unittest.TestCase):
  def setUp(self):
    self._td = tempfile.TemporaryDirectory()
    self.fixture = Path(self._td.name)
    self._art = tempfile.TemporaryDirectory()
    self.artifacts = Path(self._art.name)
    self.receipts = self.artifacts / "cert-receipts.tsv"
    self.store = self.artifacts / "store"
    # The operator creates the store before a real drive; the gate
    # refuses a missing store directory by design.
    self.store.mkdir()
    self._init_fixture_repo()

  def tearDown(self):
    self._td.cleanup()
    self._art.cleanup()

  def _init_fixture_repo(self):
    """Same shape as the dream-drive fixture: a green make-test gate,
    candidate-verification scripts copied in, one base commit."""
    subprocess.run(["git", "init", "-q", str(self.fixture)], check=True)
    src = self.fixture / "docs" / "fixture.txt"
    src.parent.mkdir(parents=True)
    src.write_text("fixture candidate\n")
    (self.fixture / "docs" / "fixture.md").write_text(
        "# doc candidate\n\nbody line\n")
    makefile = self.fixture / "Makefile"
    makefile.write_text("test:\n\t@echo fixture mock gate green\n")
    scripts_dir = self.fixture / "scripts"
    scripts_dir.mkdir()
    for name in ("verify-candidate.py", "lint-parens.py"):
      shutil.copy(ROOT / "scripts" / name, scripts_dir / name)
    subprocess.run(["git", "-C", str(self.fixture), "add", "-A"], check=True)
    subprocess.run(["git", "-C", str(self.fixture),
                    "-c", "user.email=test@example.com",
                    "-c", "user.name=test@example.com",
                    "commit", "-qm", "fixture base"], check=True)

  def run_drive(self, extra=(), candidate="docs/fixture.md"):
    env = dict(os.environ)
    env["HNGH_RECEIPTS_PATH"] = str(self.receipts)
    env.setdefault("HNGH_LOADOUT",
                   "loadout-route-label=ceremony loadout-cost-limit=2000 "
                   "loadout-token-limit=50000 loadout-time-limit=2000")
    argv = ["sbcl", "--script", str(SCRIPT), "--fast-lane",
            "--store=" + str(self.store)] + list(extra)
    argv += ["fast-lane step", candidate]
    return subprocess.run(argv, capture_output=True, text=True,
                          cwd=self.fixture, env=env, timeout=900)

  def head(self):
    return subprocess.run(
        ["git", "-C", str(self.fixture), "rev-parse", "HEAD"],
        capture_output=True, text=True, check=True).stdout.strip()

  def log_subjects(self):
    return subprocess.run(
        ["git", "-C", str(self.fixture), "log", "--format=%s"],
        capture_output=True, text=True, check=True).stdout.splitlines()

  def receipt_rows(self):
    if not self.receipts.exists():
      return []
    return [line for line in
            self.receipts.read_text().splitlines() if line.strip()]

  def test_fast_lane_refuses_substantive_change(self):
    before = self.head()
    (self.fixture / "docs" / "fixture.md").write_text(
        "# doc candidate\n\nbody line changed\n")
    out = self.run_drive()
    self.assertEqual(out.returncode, 2, out.stdout + out.stderr)
    self.assertIn("fast-lane refused", out.stdout + out.stderr)
    self.assertIn("not whitespace-only", out.stdout + out.stderr)
    self.assertEqual(before, self.head())
    self.assertEqual(self.receipt_rows(), [])

  def test_fast_lane_commits_whitespace_only(self):
    before = self.head()
    # Blank-line-only: whitespace to `git diff -w --ignore-blank-lines`
    # yet clean under verify-candidate.py's trailing-whitespace scan
    # (trailing spaces would be refused by the hygiene gate itself).
    (self.fixture / "docs" / "fixture.md").write_text(
        "# doc candidate\n\n\nbody line\n")
    out = self.run_drive()
    combined = out.stdout + out.stderr
    self.assertEqual(out.returncode, 0, combined)
    self.assertIn("fast-lane finding: candidate is whitespace-only",
                  out.stdout)
    self.assertIn("fast-lane complete:", out.stdout)
    match = re.search(r"fast-lane complete: ([0-9a-f]{64}) committed",
                      out.stdout)
    self.assertIsNotNone(match, combined)
    content_hash = match.group(1)
    self.assertNotEqual(before, self.head())
    self.assertEqual(self.log_subjects()[0],
                     "hngh: candidate " + content_hash)
    rows = self.receipt_rows()
    self.assertEqual(len(rows), 1, rows)
    fields = rows[0].split("|")
    self.assertEqual(len(fields), 4, rows[0])
    self.assertEqual(fields[1], content_hash)
    self.assertEqual(fields[2], "commit")
    self.assertRegex(fields[0], r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
    self.assertRegex(fields[3], r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")

  def test_fast_lane_requires_store(self):
    env = dict(os.environ)
    env["HNGH_RECEIPTS_PATH"] = str(self.receipts)
    out = subprocess.run(
        ["sbcl", "--script", str(SCRIPT), "--fast-lane",
         "fast-lane step", "docs/fixture.md"],
        capture_output=True, text=True, cwd=self.fixture, env=env,
        timeout=900)
    self.assertEqual(out.returncode, 2, out.stdout + out.stderr)
    self.assertIn("usage:", out.stdout)
    self.assertEqual(self.log_subjects(), ["fixture base"])

  def test_receipts_cli_append_and_cat(self):
    env = dict(os.environ)
    env["HNGH_RECEIPTS_PATH"] = str(self.receipts)
    for action, digest in (("commit", "a" * 64), ("push", "b" * 64)):
      out = subprocess.run(
          ["sbcl", "--script", str(RECEIPTS_CLI), "append", action, digest],
          capture_output=True, text=True, env=env, timeout=120)
      self.assertEqual(out.returncode, 0, out.stdout + out.stderr)
    out = subprocess.run(
        ["sbcl", "--script", str(RECEIPTS_CLI), "cat"],
        capture_output=True, text=True, env=env, timeout=120)
    self.assertEqual(out.returncode, 0, out.stdout + out.stderr)
    rows = [line for line in out.stdout.splitlines() if line.strip()]
    self.assertEqual(len(rows), 2, rows)
    self.assertEqual(rows[0].split("|")[1], "a" * 64)
    self.assertEqual(rows[0].split("|")[2], "commit")
    self.assertEqual(rows[1].split("|")[2], "push")


if __name__ == "__main__":
  unittest.main(verbosity=2)
