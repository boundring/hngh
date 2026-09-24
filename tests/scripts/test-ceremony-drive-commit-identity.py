#!/usr/bin/env python3
"""Ceremony-drive commit identity contract: the certificate-bound git
commit that the drive executes is attributed to the pinned default
operator identity, never to ambient git config.

The 2026-09-13 Fixture leak (docs/records/2026-09-16-identity-seam-
reconciliation.md) showed 42 ceremony candidates riding whatever
identity the ambient .git/config carried -- including the anonymous
fixture identity from the kernel's own test runs. The five automation
cadence writers were pinned in 0895bb5f; this closes the last seam,
the kernel ceremony executor path (scripts/ceremony-drive ->
mutation-check -> src/adapter/mutation.lisp command-for).

Contract (hermetic: disposable fixture repo, no network, no push):
- a real (non-dream) drive over a leaky-ambient fixture repo (repo-local
  user.name/user.email set to a distracting identity, no GIT_*_NAME /
  GIT_*_EMAIL in the inherited environment) commits with author AND
  committer exactly boundring <boundring@gmail.com> (2026-09-24 operator
  attribution decision);
- an operator who explicitly exports GIT_AUTHOR_* / GIT_COMMITTER_*
  keeps precedence over the defaults (the pin is a default, not a
  hijack).
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

# Fixture containment (2026-09-17): repo-selection variables are
# stripped for the whole test process so the leaky-ambient fixture repo
# below can never be re-pointed at some other repository (the
# 2026-09-13 rehearsal lane contaminated the kernel .git/config exactly
# through a hostile exported GIT_DIR).
for _HOSTILE_VAR in ("GIT_DIR", "GIT_WORK_TREE"):
  os.environ.pop(_HOSTILE_VAR, None)
for _CONFIG_VAR in ("GIT_CONFIG_GLOBAL", "GIT_CONFIG_SYSTEM"):
  os.environ.setdefault(_CONFIG_VAR, "/dev/null")

OPERATOR_NAME = "boundring"
OPERATOR_EMAIL = "boundring@gmail.com"
LEAKY_NAME = "Leaky Ambient"
LEAKY_EMAIL = "leaky@example.invalid"
IDENTITY_ENV_PREFIXES = ("GIT_AUTHOR_", "GIT_COMMITTER_")
IDENTITY_ENV_KEYS = set(IDENTITY_ENV_PREFIXES) | {"EMAIL"}


def scrubbed_env(overrides=None):
  """Inherited env with identity variables stripped, so the test never
  depends on the host's exported GIT_* identity state, and with
  repo-selection variables stripped so the drive's subprocesses can
  never resolve outside the fixture repo."""
  env = {key: value for key, value in os.environ.items()
         if not key.startswith(IDENTITY_ENV_PREFIXES)
         and key not in IDENTITY_ENV_KEYS
         and key not in ("GIT_DIR", "GIT_WORK_TREE",
                         "GIT_CONFIG_GLOBAL", "GIT_CONFIG_SYSTEM")}
  env.update(overrides or {})
  return env


class DriveCommitIdentity(unittest.TestCase):
  def setUp(self):
    self._td = tempfile.TemporaryDirectory()
    self.root = Path(self._td.name)
    self.fixture = self.root / "repo"
    self.store = self.root / "store"
    self._init_fixture_repo()

  def tearDown(self):
    self._td.cleanup()

  def _init_fixture_repo(self):
    """A fixture repo that can host a real candidate: a trivial gate
    (Makefile with a green test target) plus copies of the repo's
    candidate-verification scripts, which run relative to the drive's
    working directory. The ambient identity is deliberately leaky."""
    subprocess.run(["git", "init", "-q", str(self.fixture)], check=True)
    # The ambient identity is deliberately leaky (that is the contract
    # under test): it is pinned per commit invocation instead of written
    # into the fixture config, so no identity state lands in any repo.
    config = (
      "-c", "user.name=" + LEAKY_NAME,
      "-c", "user.email=" + LEAKY_EMAIL,
      "-c", "commit.gpgsign=false",
    )
    src = self.fixture / "docs" / "fixture.txt"
    src.parent.mkdir(parents=True)
    src.write_text("fixture candidate\n")
    makefile = self.fixture / "Makefile"
    makefile.write_text("test:\n\t@echo fixture mock gate green\n")
    scripts_dir = self.fixture / "scripts"
    scripts_dir.mkdir()
    for name in ("verify-candidate.py", "lint-parens.py"):
      shutil.copy(ROOT / "scripts" / name, scripts_dir / name)
    subprocess.run(["git", "-C", str(self.fixture), "add", "-A"], check=True)
    subprocess.run(["git", "-C", str(self.fixture), *config,
                    "commit", "-qm", "fixture base"], check=True)
    # The candidate must differ from HEAD or the certificate-bound
    # commit has nothing to commit.
    src.write_text("fixture candidate, driven\n")
    # An explicit --store must already exist (drive contract, fail-closed).
    self.store.mkdir(parents=True)

  def run_drive(self, env_overrides=None):
    return subprocess.run(
      ["sbcl", "--script", str(SCRIPT),
       "--store=" + str(self.store),
       "drive commit identity proof", "docs/fixture.txt"],
      capture_output=True, text=True, cwd=self.fixture, timeout=900,
      env=scrubbed_env(env_overrides))

  def head_identity(self):
    out = subprocess.run(
      ["git", "-C", str(self.fixture), "log", "-1",
       "--format=%an%n%ae%n%cn%n%ce"],
      capture_output=True, text=True, check=True).stdout
    lines = out.splitlines()
    self.assertEqual(4, len(lines), out)
    return lines

  def test_ambient_leak_is_pinned_to_operator_identity(self):
    out = self.run_drive()
    self.assertEqual(0, out.returncode, out.stdout + out.stderr)
    self.assertIn("committed", out.stdout)
    author_name, author_email, committer_name, committer_email = \
      self.head_identity()
    self.assertEqual(OPERATOR_NAME, author_name, out.stdout)
    self.assertEqual(OPERATOR_EMAIL, author_email, out.stdout)
    self.assertEqual(OPERATOR_NAME, committer_name, out.stdout)
    self.assertEqual(OPERATOR_EMAIL, committer_email, out.stdout)

  def test_explicit_operator_env_wins_over_defaults(self):
    out = self.run_drive(env_overrides={
      "GIT_AUTHOR_NAME": "Operator Override",
      "GIT_AUTHOR_EMAIL": "operator@example.invalid",
      "GIT_COMMITTER_NAME": "Operator Override",
      "GIT_COMMITTER_EMAIL": "operator@example.invalid",
    })
    self.assertEqual(0, out.returncode, out.stdout + out.stderr)
    author_name, author_email, committer_name, committer_email = \
      self.head_identity()
    self.assertEqual("Operator Override", author_name)
    self.assertEqual("operator@example.invalid", author_email)
    self.assertEqual("Operator Override", committer_name)
    self.assertEqual("operator@example.invalid", committer_email)


if __name__ == "__main__":
  unittest.main(verbosity=2)
