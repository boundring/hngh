#!/usr/bin/env python3
"""patrol gate-crumbs freshness, hermetic (2026-09-15 defect fix): a
gate-red crumb older than the freshness TTL must NOT produce a gate-red
fail -- it produces a single "gate-stale" finding (the alert-worthy
condition is absent/unfresh evidence, fail-closed), while a fresh red
still fails and a fresh green passes silently. Exactly-at-TTL counts as
stale. Direct check-level tests over sandbox fixtures, no real
ledgers."""

import importlib.util
import os
import subprocess
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
    spec = importlib.util.spec_from_file_location("patrol_mod_gc", SPEC)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class GateCrumbs(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.state = Path(self._td.name) / "STATE.md"
        self.db = Path(self._td.name) / "crumbs.db"
        os.environ["HNGH_CRUMBS_DB"] = str(self.db)
        self.addCleanup(os.environ.pop, "HNGH_CRUMBS_DB", None)
        os.environ["PATROL_GATE_CRUMB_TTL_S"] = "86400"
        self.addCleanup(os.environ.pop, "PATROL_GATE_CRUMB_TTL_S", None)
        self._mod = load_mod()

    def tearDown(self):
        self._td.cleanup()

    def ctx(self):
        return {"gate_label": "hngh-automation", "now": NOW}

    def crumb(self, event, ago_s, detail="hngh-automation: x"):
        with open(self.state, "a") as fh:
            fh.write("%s | 03-gate-check.sh | %s | %s\n"
                     % (iso(ago_s), event, detail))
        self._sync()

    def _sync(self):
        """fixture STATE.md -> sandbox crumbs journal (fresh db: the
        sync watermark is a byte offset, so re-imports need a clean db)."""
        self.db.unlink(missing_ok=True)
        subprocess.run([sys.executable, str(ROOT / "lib" / "crumbs-db.py"),
                        "sync", "--state", str(self.state),
                        "--db", str(self.db)],
                       check=True, capture_output=True)

    def test_stale_red_does_not_report_gate_red(self):
        self.crumb("gate-red", 86400 + 3600)
        out = self._mod.check_gate_crumbs(self.ctx())
        self.assertNotIn(("hngh-automation", "gate-red", "hngh-automation: x"),
                         out["fails"])
        self.assertEqual(len(out["fails"]), 1)
        self.assertEqual(out["fails"][0][1], "gate-stale")

    def test_fresh_red_still_fails(self):
        self.crumb("gate-red", 600)
        out = self._mod.check_gate_crumbs(self.ctx())
        self.assertEqual(out["fails"],
                         [("hngh-automation", "gate-red",
                           "hngh-automation: x")])

    def test_fresh_green_passes(self):
        self.crumb("gate-green", 600)
        out = self._mod.check_gate_crumbs(self.ctx())
        self.assertEqual(out["fails"], [])
        self.assertEqual(len(out["passes"]), 1)

    def test_no_crumbs_is_gate_stale(self):
        out = self._mod.check_gate_crumbs(self.ctx())
        self.assertEqual(out["fails"],
                         [("hngh-automation", "gate-stale",
                           "no gate crumb found")])

    def test_exactly_at_ttl_is_stale(self):
        self.crumb("gate-red", 86400)
        out = self._mod.check_gate_crumbs(self.ctx())
        self.assertEqual(out["fails"][0][1], "gate-stale")

    def test_stale_finding_dedups_by_identity(self):
        """The stale finding keeps one stable (surface, cause) identity
        across episodes so the report path dedups instead of streaming."""
        self.crumb("gate-red", 86400 + 60)
        out1 = self._mod.check_gate_crumbs(self.ctx())
        self._td2 = tempfile.TemporaryDirectory()
        self.state = Path(self._td2.name) / "STATE.md"
        self.db = Path(self._td2.name) / "crumbs.db"
        os.environ["HNGH_CRUMBS_DB"] = str(self.db)
        self.crumb("gate-red", 86400 + 7200)
        out2 = self._mod.check_gate_crumbs(self.ctx())
        id1 = out1["fails"][0][:2]
        id2 = out2["fails"][0][:2]
        self.assertEqual(id1, id2)

    def test_newest_within_window_wins(self):
        """A fresh green after a stale red is green: newest-fresh-wins."""
        self.crumb("gate-red", 86400 + 60)
        self.crumb("gate-green", 600)
        out = self._mod.check_gate_crumbs(self.ctx())
        self.assertEqual(out["fails"], [])
        self.assertEqual(len(out["passes"]), 1)


if __name__ == "__main__":
    unittest.main(verbosity=2)
