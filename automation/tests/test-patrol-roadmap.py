#!/usr/bin/env python3
"""roadmap/rotation patrol checks, hermetic (2026-09-15 fold): a
landing stage whose roadmap/records movement is older than the
staleness window fires stage-stale, a recent movement stays silent
(boundary: exactly the window fires); a queue Next item held >= the
rotation window fires rotation-due, and changing the Next item resets
the watch row; both checks fail soft (pass, dormant) when their
fixture surfaces are absent. Git history is stubbed via
PATROL_ROADMAP_GIT_LOG (the journalctl-stub convention) so no test
touches the real repository history."""

import importlib.util
import os
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / "jobs" / "patrol.py"
NOW = time.mktime(time.strptime("2026-09-15T12:00:00Z",
                                "%Y-%m-%dT%H:%M:%SZ")) - time.timezone


def iso(ago_s):
    return time.strftime("%Y-%m-%dT%H:%M:%SZ",
                         time.gmtime(NOW - ago_s))


def load_mod():
    spec = importlib.util.spec_from_file_location("patrol_mod", SPEC)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class RoadmapRotation(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.sb = Path(self._td.name)
        self.kernel = self.sb / "kernel"
        (self.kernel / "docs" / "project").mkdir(parents=True)
        (self.sb / "state").mkdir()
        # fixture roadmap: stages 2 and 3 both landing (live shape)
        (self.kernel / "docs" / "project" / "roadmap.md").write_text(
            "| Stage | Scope | Exit | Status |\n"
            "|---|---|---|---|\n"
            "| **1 — Ledger** | x | y | **green** |\n"
            "| **2 — One interface** | tabs | render | **landing** |\n"
            "| **3 — The Governed Fleet** | fleet | invariants | "
            "**landing** |\n")
        (self.kernel / "docs" / "project" / "queue.md").write_text(
            "id\tstatus\ttitle\tevidence\n"
            "```\n"
            "some-item\tqueued\tSomething\t...\n"
            "```\n"
            "## Next\n"
            "\n"
            "- **node-lattice-admission** - rotate next (unblocked)\n"
            "\n"
            "## Scheduling\n")
        self.gitlog = self.sb / "gitlog.tsv"
        os.environ["PATROL_ROADMAP_GIT_LOG"] = str(self.gitlog)
        os.environ["PATROL_ROTATION_WATCH"] = str(
            self.sb / "state" / "rotation-watch.tsv")
        self._mod = load_mod()

    def tearDown(self):
        self._td.cleanup()
        for k in ("PATROL_ROADMAP_GIT_LOG", "PATROL_ROTATION_WATCH"):
            os.environ.pop(k, None)

    def ctx(self):
        return {"kernel": str(self.kernel), "root": str(self.sb / "auto"),
                "now": NOW, "queue": str(
                    self.kernel / "docs" / "project" / "queue.md"),
                "roadmap": str(
                    self.kernel / "docs" / "project" / "roadmap.md"),
                "rotation_watch": str(
                    self.sb / "state" / "rotation-watch.tsv")}

    # --- roadmap-stale -----------------------------------------------

    def test_stage2_stale_stage3_recent(self):
        """The live expectation: stage-2's row untouched since 08-26
        fires; stage-3 moved by the 2026-09-13 governed-fleet record
        and stays silent (now = 09-15, window 14d)."""
        self.gitlog.write_text(
            "%d\tGoverned Fleet consolidation\tdocs/records/"
            "2026-09-13-governed-fleet.md\n"
            % (NOW - 2 * 86400) +
            "%d\tstage 2 frontier note\tdocs/project/roadmap.md\n"
            % (NOW - 20 * 86400))
        r = self._mod.check_roadmap_stale(self.ctx())
        self.assertEqual([(a, c) for a, c, _ in r["fails"]],
                         [("stage2", "stage2-stale")])
        self.assertTrue(any(p[0] == "stage3" for p in r["passes"]))

    def test_boundary_exactly_14d_fires(self):
        """Movement exactly at the 14d window is stale (>= window)."""
        self.gitlog.write_text(
            "%d\tstage 2 polish\tdocs/project/roadmap.md\n"
            % (NOW - 14 * 86400) +
            "%d\tstage 3 invariant\tdocs/project/roadmap.md\n"
            % (NOW - 86400))
        r = self._mod.check_roadmap_stale(self.ctx())
        self.assertEqual([c for _, c, _ in r["fails"]], ["stage2-stale"])

    def test_recent_movement_silent(self):
        self.gitlog.write_text(
            "%d\tstage 2 deep-links\tdocs/project/roadmap.md\n"
            % (NOW - 13 * 86400) +
            "%d\tstage 3 invariant\tdocs/project/roadmap.md\n"
            % (NOW - 2 * 86400))
        r = self._mod.check_roadmap_stale(self.ctx())
        self.assertEqual(r["fails"], [])

    def test_movement_via_record_filename(self):
        """stage<N> in a docs/records file NAME counts as movement."""
        self.gitlog.write_text(
            "%d\tLanding slice\tdocs/records/2026-09-14-stage2-wake.md\n"
            % (NOW - 86400) +
            "%d\tstage 3 invariant\tdocs/project/roadmap.md\n"
            % (NOW - 86400))
        r = self._mod.check_roadmap_stale(self.ctx())
        self.assertEqual(r["fails"], [])

    def test_missing_roadmap_dormant(self):
        (self.kernel / "docs" / "project" / "roadmap.md").unlink()
        r = self._mod.check_roadmap_stale(self.ctx())
        self.assertEqual(r["fails"], [])
        self.assertTrue(r["passes"])

    # --- rotation-due -------------------------------------------------

    def test_rotation_due_at_7d(self):
        (self.sb / "state" / "rotation-watch.tsv").write_text(
            "node-lattice-admission\t%s\n" % iso(7 * 86400))
        r = self._mod.check_rotation_due(self.ctx())
        self.assertEqual([(a, c) for a, c, _ in r["fails"]],
                         [("node-lattice-admission", "rotation-due")])

    def test_rotation_young_quiet_and_no_row_reset(self):
        (self.sb / "state" / "rotation-watch.tsv").write_text(
            "node-lattice-admission\t%s\n" % iso(6 * 86400))
        r = self._mod.check_rotation_due(self.ctx())
        self.assertEqual(r["fails"], [])
        self.assertEqual(
            (self.sb / "state" / "rotation-watch.tsv").read_text(),
            "node-lattice-admission\t%s\n" % iso(6 * 86400))

    def test_next_change_resets_watch_row(self):
        (self.sb / "state" / "rotation-watch.tsv").write_text(
            "bridge-operator-host\t%s\n" % iso(30 * 86400))
        r = self._mod.check_rotation_due(self.ctx())
        self.assertEqual(r["fails"], [])
        row = (self.sb / "state" / "rotation-watch.tsv").read_text()
        self.assertEqual(row,
                         "node-lattice-admission\t%s\n" % iso(0))

    def test_rotation_creates_row_when_missing(self):
        r = self._mod.check_rotation_due(self.ctx())
        self.assertEqual(r["fails"], [])
        self.assertEqual(
            (self.sb / "state" / "rotation-watch.tsv").read_text(),
            "node-lattice-admission\t%s\n" % iso(0))

    def test_missing_queue_dormant(self):
        (self.kernel / "docs" / "project" / "queue.md").unlink()
        r = self._mod.check_rotation_due(self.ctx())
        self.assertEqual(r["fails"], [])
        self.assertTrue(r["passes"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
