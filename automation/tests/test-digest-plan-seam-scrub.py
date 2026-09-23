#!/usr/bin/env python3
"""digest-ledger plan-seam scrub contract (llc-digest-ledger-redaction
follow-through, red-first 2026-09-16): the sessions 'last_plan' quote
and the plans 'queue_next' quote transit the public digest mega line,
so they must carry no machine-local path tokens. Live evidence: budget
ledger first-lines carry absolute paths, STATE.md alert crumbs carry
token paths (2026-09-16 credential-freshness), and plans.json
queue_next is free-form plan text. Hermetic: feed paths are pointed at
a sandbox via the module's globals."""

import importlib.util
import os
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # automation/
HOME = os.path.expanduser("~")


def _load(name, rel):
    spec = importlib.util.spec_from_file_location(name, str(ROOT / rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_pristine = _load("digest_ledger_pristine", "jobs/digest-ledger.py")
_sessions = _pristine.sessions
_plans = _pristine.plans


class PlanSeamScrub(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.sb = Path(self._td.name)
        self.dl = _load("digest_ledger_%d" % id(self),
                        "jobs/digest-ledger.py")
        self.budget = self.sb / "budget.md"
        self.plans = self.sb / "plans.json"
        # feed functions bind their paths as default args at def time;
        # rebind them to the sandbox (live reads: sessions reads the
        # budget ledger, plans reads plans.json; everything else empty).
        self.dl.sessions = (
            lambda date, path=str(self.budget): _sessions(date, path))
        self.dl.plans = (
            lambda date, path=str(self.plans): _plans(date, path))
        self.dl.spend = lambda date: None
        self.dl.operator_items = lambda: ([], [], [])
        self.dl.research_lines = lambda: {}
        self.dl.posture = lambda date: []

    def tearDown(self):
        self._td.cleanup()

    def build(self):
        return "\n".join(self.dl.build("2026-09-16", feeds={}))

    def test_last_plan_carries_no_home_path(self):
        # real carrier: night-session.sh appends 'ts | LABEL | session-run'
        # with caller-supplied LABEL in the lane field, and build() prints
        # that field as 'newest:'.
        self.budget.write_text(
            f"2026-09-16T10:00Z | fix {HOME}/secret leak"
            " | session-run\n",
            encoding="utf-8")
        out = self.build()
        self.assertIn("- sessions:", out)
        self.assertNotIn(HOME, out)
        self.assertIn("[redacted path]", out)

    def test_last_plan_carries_no_tmp_or_tilde_path(self):
        self.budget.write_text(
            "2026-09-16T10:00Z | wrote /tmp/vr-42 and ~/.hngh/x"
            " | session-run\n",
            encoding="utf-8")
        out = self.build()
        self.assertNotIn("/tmp/vr-42", out)
        self.assertNotIn("~/.hngh", out)

    def test_queue_next_carries_no_home_path(self):
        self.plans.write_text(
            '{"plans": [], "queue_next": '
            f'"land {HOME}/Projects/etc/hngh fix", '
            '"accepted": [], "executed": []}', encoding="utf-8")
        out = self.build()
        self.assertIn("- plans:", out)
        self.assertNotIn(HOME, out)
        self.assertIn("[redacted path]", out)

    def test_queue_next_carries_no_root_or_users_path(self):
        self.plans.write_text(
            '{"plans": [], "queue_next": "audit /root/.ssh + /Users/b/d", '
            '"accepted": [], "executed": []}', encoding="utf-8")
        out = self.build()
        self.assertNotIn("/root/.ssh", out)
        self.assertNotIn("/Users/b", out)

    def test_clean_plan_text_untouched(self):
        self.plans.write_text(
            '{"plans": [], "queue_next": "key-rotation-freshness", '
            '"accepted": [], "executed": []}', encoding="utf-8")
        out = self.build()
        self.assertIn("queue next: key-rotation-freshness.", out)


if __name__ == "__main__":
    unittest.main()
