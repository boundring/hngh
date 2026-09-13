#!/usr/bin/env python3
"""plan-feed work-graph contract (visualization rung 1, step 1).

Hermetic: fixture plans in a temp root, env-seam like the PlanFeed
harness in test-plan-acceptance.py. Covers step parsing (state,
titles, Verification names incl. wrapped lines), priority/cause
front-matter extraction, edge extraction from execution notes, and
per-plan failure isolation with an alert row.
Edged vocabulary is deliberately minimal and documented in
jobs/plan-feed.py: edges come ONLY from lines matching the fixed
convention; prose that does not match emits no edge (honesty rule:
blocked-by drawn only from real evidence).
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLAN_FEED = ROOT / "jobs" / "plan-feed.py"


class PlanFeedGraph(unittest.TestCase):
    def run_feed(self, plans):
        with tempfile.TemporaryDirectory() as td:
            home = Path(td) / "kernel"
            (home / "docs" / "project" / "plans").mkdir(parents=True)
            for name, text in plans.items():
                (home / "docs" / "project" / "plans" / name).write_text(text)
            out = Path(td) / "plans.json"
            env = {**os.environ, "HNGH_HOME": str(home),
                   "HNGH_PLANS_FEED_OUT": str(out), "DRY_RUN": "0",
                   "HNGH_CEREMONY_LOG": ""}
            r = subprocess.run([sys.executable, str(PLAN_FEED)], env=env,
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            return json.loads(out.read_text())

    def test_steps_parsed_with_verification_names(self):
        # step list shapes: plain titles, numbered, wrapped verification
        text = ("<!-- plan: status=accepted risk=normal accepted=t -->\n"
                "# p\n\n## Steps\n\n"
                "- [x] 1. seed the ledger\n"
                "      Verification: make test green.\n"
                "- [ ] 2. render the graph\n"
                "      Verification: suite test covers step parsing,\n"
                "      edge extraction, and per-plan failure isolation;\n"
                "      make dashboard green.\n"
                "- [x] no-verification step\n")
        feed = self.run_feed({"2026-09-09-p.plan.md": text})
        p = feed["plans"][0]
        steps = p["steps"]
        self.assertEqual(len(steps), 3)
        self.assertEqual(steps[0], {"n": 1, "title": "seed the ledger",
                                    "done": True,
                                    "verification": "make test green"})
        self.assertEqual(steps[1]["done"], False)
        self.assertEqual(
            steps[1]["verification"],
            "suite test covers step parsing, "
            "edge extraction, and per-plan failure isolation; "
            "make dashboard green")
        self.assertEqual(steps[2]["verification"], "")
        # legacy summary fields unchanged
        self.assertEqual(p["steps_total"], 3)
        self.assertEqual(p["steps_done"], 2)

    def test_priority_and_cause_frontend(self):
        high = ("<!-- plan: status=accepted risk=normal priority=high "
                "accepted=t -->\n# p\n\n## Steps\n\n- [x] one: t\n")
        park = ("<!-- plan: status=parked risk=normal accepted=t "
                "cause=duplicate -->\n# q\n\n## Steps\n\n- [x] one: t\n")
        plain = ("<!-- plan: status=proposed risk=normal accepted=- -->\n"
                 "# r\n\n## Steps\n\n- [x] one: t\n")
        feed = self.run_feed({"a.plan.md": high, "b.plan.md": park,
                              "c.plan.md": plain})
        by_slug = {p["slug"][0]: p for p in feed["plans"]}
        self.assertEqual(by_slug["a"]["priority"], "high")
        self.assertIsNone(by_slug["a"]["cause"])
        self.assertEqual(by_slug["b"]["cause"], "duplicate")
        self.assertIsNone(by_slug["b"]["priority"])
        # no invented defaults for plans whose front-matter omits them
        self.assertIsNone(by_slug["c"]["priority"])
        self.assertIsNone(by_slug["c"]["cause"])
        # a parked plan with a cause carries a parked-because edge,
        # drawn only from the real front-matter
        edges_b = by_slug["b"]["edges"]
        self.assertEqual(
            edges_b,
            [{"type": "parked-because", "cause": "duplicate",
              "from": None, "to": None}])
        self.assertEqual(by_slug["a"]["edges"], [])
        self.assertEqual(by_slug["c"]["edges"], [])

    def test_edges_from_execution_notes_convention(self):
        # fixed convention only: "- Step N unlocks Step M" /
        # "- Step N feeds Step M"; free prose emits no edge
        text = ("<!-- plan: status=accepted risk=normal accepted=t -->\n"
                "# p\n\n## Steps\n\n"
                "- [ ] 1. foundation\n"
                "- [ ] 2. consumer\n"
                "- [ ] 3. last\n\n"
                "## Execution notes\n\n"
                "- Step 2 and 3 both consume it; step 1 is the base.\n"
                "- Step 1 unlocks Step 2.\n"
                "- Step 1 feeds Step 3.\n"
                "- Step 9 unlocks Step 99.\n")
        feed = self.run_feed({"p.plan.md": text})
        edges = feed["plans"][0]["edges"]
        self.assertIn({"type": "unlocks", "from": 1, "to": 2}, edges)
        self.assertIn({"type": "feeds", "from": 1, "to": 3}, edges)
        self.assertIn({"type": "unlocks", "from": 9, "to": 99}, edges)
        # unrelated prose emitted no edge
        self.assertEqual(len(edges), 3)

    def test_per_plan_failure_isolation_and_alert_row(self):
        good = ("<!-- plan: status=proposed risk=normal accepted=- -->\n"
                "# p\n\n## Steps\n\n- [x] one: fine\n")
        bad = ("<!-- plan: status=proposed risk=normal accepted=- -->\n"
               "# q\n\n## Steps\n\n- [q] one: malformed checkbox marker\n")
        feed = self.run_feed({"a-good.plan.md": good,
                              "b-bad.plan.md": bad})
        good_plan, bad_plan = feed["plans"][0], feed["plans"][1]
        # the corrupt plan fails closed: no steps emitted, summary stays
        self.assertEqual(good_plan["steps"],
                         [{"n": 1, "title": "fine", "done": True,
                           "verification": ""}])
        self.assertEqual(bad_plan.get("steps"), [])
        self.assertEqual(bad_plan["steps_total"], 0)  # legacy count: bad marker is not a step
        self.assertTrue(bad_plan.get("parse_error"))
        # the feed carries an alert row and the other plan still emits
        alerts = feed["alerts"]
        self.assertEqual(len(alerts), 1)
        self.assertEqual(alerts[0]["slug"], "b-bad")
        self.assertIn("checkbox", alerts[0]["detail"])

    def test_legacy_summary_fields_byte_compatible(self):
        # the pre-existing fields for these fixtures must be exactly
        # what the old emitter produced (name, status, risk, accepted,
        # steps_total, steps_done)
        text = ("<!-- plan: status=holding risk=weird accepted=x -->\n"
                "# p\n\n## Steps\n\n- [x] a: t\n- [ ] b: t\n")
        feed = self.run_feed({"p.plan.md": text})
        p = feed["plans"][0]
        for key, val in (("slug", "p"), ("status", "holding"),
                         ("risk", "weird"), ("accepted", "x"),
                         ("steps_total", 2), ("steps_done", 1)):
            self.assertEqual(p[key], val)
        # unknown status words must not be silently rewritten
        text2 = ("<!-- plan: status=held risk=normal accepted=- "
                 "cause=missing-design -->\n# q\n\n## Steps\n\n"
                 "- [ ] one: t\n      Verification: make test\n")
        feed = self.run_feed({"q.plan.md": text2})
        self.assertEqual(feed["plans"][0]["status"], "held")
        self.assertEqual(feed["plans"][0]["cause"], "missing-design")
        self.assertEqual(feed["plans"][0]["steps"][0]["verification"],
                         "make test")


if __name__ == "__main__":
    unittest.main()
