#!/usr/bin/env python3
"""email-digest compose() doctrine upgrades (2026-09-27 course-correction
slice 2, three-digests-a-day): (i) a "feedback backlog" headline line —
open operator-item count + oldest first_seen + up to 3 subject snippets
from dashboard/operator-items.json, absent file = silent omit; (ii) the
"Read today's paper" newspaper link in the footer; (iii) the ghost-voice
editorial line via lib/ghost-voices.py ghost_counsel — silently omitted
while the module/KB is absent (slice 4 lands it). Hermetic: module
loaded with HNGH_AUTOMATION_ROOT / HNGH_HOME in a sandbox."""

import importlib.util
import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DIGEST = ROOT / "scripts" / "email-digest.py"


def load():
    spec = importlib.util.spec_from_file_location("email_digest_upg", DIGEST)
    mod = importlib.util.module_from_spec(spec)
    sys.modules["email_digest_upg"] = mod
    spec.loader.exec_module(mod)
    return mod


G = dict(day="2026-09-27", tel=None, alerts24=[], prog="prog", delta=0,
         pending=0, spend_t="", spend_y="", klines=[], alines=[],
         fresh=[], untracked=[], have_prev=False, lessons="", night="",
         bench="", qa="")


class ComposeUpgrades(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="digest-upg-"))
        self.addCleanup(lambda: __import__("shutil").rmtree(
            self.tmp, True))
        (self.tmp / "dashboard").mkdir()
        (self.tmp / "digest").mkdir()
        self.old = {k: os.environ.get(k) for k in
                    ("HNGH_AUTOMATION_ROOT", "HNGH_HOME")}
        os.environ["HNGH_AUTOMATION_ROOT"] = str(self.tmp)
        os.environ["HNGH_HOME"] = str(self.tmp)
        self.addCleanup(self._restore)
        self.ed = load()

    def _restore(self):
        for k, v in self.old.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v

    def write_items(self, items):
        with open(self.tmp / "dashboard" / "operator-items.json", "w") as fh:
            json.dump({"generated_at": "2026-09-27T00:00:00Z",
                       "items": items}, fh)

    def compose(self):
        return self.ed.compose(dict(G))

    def test_feedback_backlog_line(self):
        self.write_items([
            {"id": "a1", "text": "feedback-ingest | alert | [feedback:idea] "
             "from email the digest should surface the backlog",
             "first_seen": "2026-09-20T10:00:00Z", "status": "open"},
            {"id": "a2", "text": "feedback-ingest | alert | "
             "[feedback:bug] dashboard renders blank on cold start",
             "first_seen": "2026-09-25T11:00:00Z", "status": "open"},
            {"id": "a3", "text": "already handled item",
             "first_seen": "2026-09-19T09:00:00Z", "status": "handled"},
        ])
        out = self.compose()
        self.assertIn("feedback backlog: 2 open item(s)", out)
        self.assertIn("oldest 2026-09-20T10:00:00Z", out)
        self.assertIn("[feedback:idea]", out)
        self.assertIn("[feedback:bug]", out)
        self.assertNotIn("already handled item", out)

    def test_feedback_backlog_absent_is_silent(self):
        out = self.compose()
        self.assertNotIn("feedback backlog", out)

    def test_newspaper_link_in_footer(self):
        out = self.compose()
        self.assertIn("http://127.0.0.1:8890/newspaper.html", out)

    def test_ghost_line_absent_is_silent(self):
        # lib/ghost-voices.py does not exist yet (slice 4): compose must
        # not crash and must not print a ghost editorial line
        out = self.compose()
        self.assertNotIn("editorial:", out)


if __name__ == "__main__":
    unittest.main()
