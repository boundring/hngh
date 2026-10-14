#!/usr/bin/env python3
"""The patrol ceremony seam must supply a loadout, not inherit one.

2026-10-14. The gate-cure patrol (automation/jobs/patrol.py
cure_red_gate -> _drive_ceremony) drives scripts/ceremony-drive through
subprocess. ceremony-drive's cost-and-route-discipline reads its four
fact values out of HNGH_LOADOUT (scripts/ceremony-drive:156 loadout-
fact-values) and refuses fail-closed when a key is missing. The
automation config declares HNGH_LOADOUT (automation/config.env:102), but
assigns it as a plain shell variable; config.env's own export-discipline
note (lines 97-100) says unexported values do not cross a python child
env. So the drive inherited no loadout and every automated cure refused
at the ceremony step -- the lane was dead and looked merely idle.

This is the check-the-checker test for that seam, hermetic (no drive, no
network, no store): a stub PATROL_CEREMONY_BIN records the environment it
was handed, and the contract is asserted on what actually reached the
child.

- with no HNGH_LOADOUT in the environment, the stub sees a loadout
  carrying all four keys ceremony-drive requires;
- an operator who exports HNGH_LOADOUT keeps precedence (the default is
  a default, not a hijack), matching scripts/omp-bridge:397.
"""

import importlib.util
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
PATROL = ROOT / "automation" / "jobs" / "patrol.py"

REQUIRED_KEYS = ("loadout-route-label", "loadout-cost-limit",
                 "loadout-token-limit", "loadout-time-limit")

# The stub reports the child's view of the environment on stdout; the
# seam returns the LAST stdout line, so this one line is what the test
# reads. Not JSON: the seam takes the tail verbatim.
STUB = """#!/usr/bin/env python3
import os
print("SEES:" + os.environ.get("HNGH_LOADOUT", "<ABSENT>"))
"""


def load_patrol():
  spec = importlib.util.spec_from_file_location("patrol_under_test", PATROL)
  module = importlib.util.module_from_spec(spec)
  spec.loader.exec_module(module)
  return module


def loadout_keys(value):
  """The set of key= tokens in a space-separated HNGH_LOADOUT value."""
  return {token.split("=", 1)[0]
          for token in value.split() if "=" in token}


class CeremonySeamLoadoutTest(unittest.TestCase):

  def setUp(self):
    self.patrol = load_patrol()
    self.stub_dir = tempfile.mkdtemp(prefix="patrol-seam-stub-")
    stub = Path(self.stub_dir) / "ceremony-stub"
    stub.write_text(STUB, encoding="utf-8")
    stub.chmod(0o755)
    self.saved = os.environ.pop("HNGH_LOADOUT", None)
    self.saved_bin = os.environ.get("PATROL_CEREMONY_BIN")
    os.environ["PATROL_CEREMONY_BIN"] = str(stub)

  def _real_drive_fixture(self, root):
    """A fixture repo the REAL ceremony-drive can certify and commit: a
    trivial green gate, the candidate-verification scripts copied in,
    and a .md conclusion file (source-grounding refuses a candidate
    with no citable source). Mirrors the fixture convention of
    test-ceremony-drive-commit-identity.py. No origin, so the drive
    commits and skips the push leg."""
    repo = root / "repo"
    subprocess.run(["git", "init", "-q", str(repo)], check=True)
    config = ("-c", "user.name=boundring",
              "-c", "user.email=boundring@gmail.com",
              "-c", "commit.gpgsign=false")
    (repo / "docs").mkdir(parents=True)
    (repo / "docs" / "fixture-note.md").write_text("fixture candidate\n")
    (repo / "Makefile").write_text("test:\n\t@echo fixture mock gate green\n")
    (repo / "scripts").mkdir()
    for name in ("verify-candidate.py", "lint-parens.py"):
      shutil.copy(ROOT / "scripts" / name, repo / "scripts" / name)
    subprocess.run(["git", "-C", str(repo), "add", "-A"], check=True)
    subprocess.run(["git", "-C", str(repo), *config,
                    "commit", "-qm", "fixture base"], check=True)
    # The candidate must differ from HEAD or there is nothing to commit.
    (repo / "docs" / "fixture-note.md").write_text(
        "fixture candidate, driven by the patrol seam\n")
    return repo

  def tearDown(self):
    os.environ.pop("HNGH_LOADOUT", None)
    if self.saved is not None:
      os.environ["HNGH_LOADOUT"] = self.saved
    if self.saved_bin is None:
      os.environ.pop("PATROL_CEREMONY_BIN", None)
    else:
      os.environ["PATROL_CEREMONY_BIN"] = self.saved_bin

  def drive_with_stub(self):
    rc, tail = self.patrol._drive_ceremony(
        str(ROOT), "seam loadout contract", ["docs/project/decisions.md"])
    self.assertEqual(rc, 0, tail)
    self.assertTrue(tail.startswith("SEES:"), tail)
    return tail[len("SEES:"):]

  def test_seam_supplies_a_loadout_when_none_is_inherited(self):
    # The regression itself: the stub is handed a loadout even though
    # nothing in the ambient environment exports one.
    value = self.drive_with_stub()
    self.assertNotEqual(value, "<ABSENT>",
                         "the seam handed the drive no HNGH_LOADOUT; "
                         "cost-and-route-discipline would refuse")
    self.assertEqual(set(REQUIRED_KEYS) - loadout_keys(value), set(),
                     "incomplete loadout: %s" % value)

  def test_exported_loadout_takes_precedence(self):
    # A default, not a hijack: scripts/omp-bridge:397 sets it up the
    # same way so an operator can raise limits for one invocation.
    operator = ("loadout-route-label=operator loadout-context-limit=2000 "
                "loadout-token-limit=50000 loadout-cost-limit=2000 "
                "loadout-time-limit=1800")
    os.environ["HNGH_LOADOUT"] = operator
    self.assertEqual(self.drive_with_stub(), operator)

  def test_config_env_loadout_stays_unexported_but_complete(self):
    # config.env declares the value but does not export it. That stays
    # true -- the fix belongs at the seam, not in the env file, so the
    # no-export note keeps meaning what it says. What must hold is that
    # the declared value itself carries all four keys, since it is what
    # hngh-record.sh:26 feeds create-run.
    text = (ROOT / "automation" / "config.env").read_text(encoding="utf-8")
    declared = [ln for ln in text.splitlines()
                if ln.startswith("HNGH_LOADOUT=")]
    self.assertEqual(len(declared), 1,
                     "expected exactly one HNGH_LOADOUT assignment")
    self.assertFalse(declared[0].startswith("export "),
                     "config.env must not export HNGH_LOADOUT: the seam "
                     "supplies it, and an export here would silently "
                     "override the operator's own env on every job")
    value = declared[0].split("=", 1)[1].strip().strip('"')
    self.assertEqual(set(REQUIRED_KEYS) - loadout_keys(value), set(),
                     "config.env loadout missing a required key: %s" % value)

  def test_real_drive_commits_through_the_seam_with_no_inherited_loadout(self):
    # The acceptance-level check: not "the seam passes an env" but "a
    # real ceremony, with nothing in the environment to inherit,
    # reaches a passing verdict and commits the candidate". Measured
    # head-to-head on 2026-10-14: the unfixed seam returned rc=1 with
    # cost-and-route-discipline refused and the fixture HEAD still at
    # "fixture base"; this seam returns rc=0 with the certificate
    # commit landed. Slow (a real sbcl drive) but it is the only
    # assertion that distinguishes a working lane from a plausible one.
    os.environ["PATROL_CEREMONY_BIN"] = str(ROOT / "scripts"
                                           / "ceremony-drive")
    with tempfile.TemporaryDirectory() as tmp:
      repo = self._real_drive_fixture(Path(tmp))
      rc, tail = self.patrol._drive_ceremony(
          str(repo), "gate-cure seam end to end proof",
          ["docs/fixture-note.md"])
      head = subprocess.run(
          ["git", "-C", str(repo), "log", "--oneline", "-1"],
          capture_output=True, text=True, check=True).stdout.strip()
      self.assertEqual(rc, 0, tail)
      self.assertIn("hngh: candidate", head)
      self.assertNotIn("fixture base", head)

  def test_patrol_subprocess_receives_an_explicit_env(self):
    # The mechanism, pinned so a later "simplification" that drops the
    # env= argument is caught even if the default is changed.
    source = PATROL.read_text(encoding="utf-8")
    start = source.index("def _drive_ceremony")
    body = source[start:source.index("\ndef ", start + 1)]
    self.assertIn("env=env", body,
                  "_drive_ceremony must pass an explicit env to subprocess")
    self.assertIn('setdefault(\n        "HNGH_LOADOUT"', body,
                  "_drive_ceremony must default HNGH_LOADOUT")


if __name__ == "__main__":
  unittest.main()
