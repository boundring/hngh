#!/usr/bin/env python3
"""curator-beat contract (rehearsal-lane plan step 3).

Hermetic: fixture kernel trees + dashboard/plans.json built by
jobs/plan-feed.py (the feed the curator consumes). Covers the two
machine actions (priority flag, duplicate-scope merge proposal) and
the two report verbs (deck handoff, enabling-work staging), the
2026-09-09 disposition-sweep guardrails (never risk=critical, never
already-parked, landed steps mean no park, references must exist),
and the no-op case. The cadence wrapper is exercised end to end with
HNGH_CRUMBS_DB/HNGH_HOME seams: operator-item rows only, plan files
untouched, repeat rows deduped.
"""

import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CURATOR = ROOT / "jobs" / "curator-beat.py"
PLAN_FEED = ROOT / "jobs" / "plan-feed.py"
WRAPPER = ROOT / "cadence" / "calendar" / "daily" / "16-curator-beat.sh"
CRUMBS_DB_PY = ROOT / "lib" / "crumbs-db.py"


def crumbs_export(db):
    """The journal's rendered 4-field lines (the derived STATE.md shape)."""
    r = subprocess.run([sys.executable, str(CRUMBS_DB_PY), "export",
                        "--db", str(db)], capture_output=True, text=True)
    return r.stdout.splitlines()


def plan(status="accepted", risk="normal", accepted="2026-09-01T00:00:00Z",
         routed=None, steps=1, done=0, body="", title="plan", cause=None):
    front = f"<!-- plan: status={status} risk={risk} accepted={accepted}"
    if routed:
        front += f" routed-from={routed}"
    if cause:
        front += f" cause={cause}"
    front += " -->"
    if body and not body.startswith("\n"):
        body = "\n" + body
    return (f"{front}\n# {title}\n" + body + "\n\n## Steps\n\n"
            + "".join(f"- {'[x]' if i < done else '[ ]'} {i+1}. step {i+1}\n"
                      for i in range(steps)))


class CuratorBeat(unittest.TestCase):
    def curate(self, plans, queue_next=None):
        """Run plan-feed + curator against a fixture kernel; return
        (rc, emission lines, kernel path)."""
        with tempfile.TemporaryDirectory() as td:
            home = Path(td) / "kernel"
            plans_dir = home / "docs" / "project" / "plans"
            plans_dir.mkdir(parents=True)
            for name, text in plans.items():
                (plans_dir / name).write_text(text)
            q = (home / "docs" / "project" / "queue.md")
            q.write_text("id\tstatus\ttitle\tevidence\n"
                         "x\tqueued\tX\tbacklog\n"
                         + ("## Next\n\n- **wake-mutation-lane**\n"
                            if queue_next else ""))
            out = Path(td) / "plans.json"
            env = {**os.environ, "HNGH_HOME": str(home),
                   "HNGH_PLANS_FEED_OUT": str(out), "DRY_RUN": "0",
                   "HNGH_CEREMONY_LOG": ""}
            r = subprocess.run([sys.executable, str(PLAN_FEED)], env=env,
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            r = subprocess.run([sys.executable, str(CURATOR)], env=env,
                               capture_output=True, text=True)
            return r.returncode, r.stdout.splitlines(), home

    def flag_lines(self, lines):
        return [l for l in lines if l.startswith("flagged\t")]

    def test_flag_fires_for_referenced_never_started_plan(self):
        rc, lines, _ = self.curate({
            "2026-09-01-live.plan.md": plan(
                body="This plan is the enabler for "
                     "docs/project/plans/2026-09-02-integration.plan.md"),
            "2026-09-02-integration.plan.md": plan(accepted="2026-09-02T00:00:00Z"),
        })
        self.assertEqual(rc, 0)
        flags = self.flag_lines(lines)
        self.assertEqual(len(flags), 1)
        self.assertIn("2026-09-02-integration", flags[0])
        self.assertIn("priority=high", flags[0])
        self.assertIn("2026-09-01-live", flags[0])

    def test_flag_needs_a_live_referencing_plan(self):
        # accepted, zero steps, but nothing references it: no action
        rc, lines, _ = self.curate({
            "2026-09-01-lone.plan.md": plan(),
        })
        self.assertEqual(rc, 0)
        self.assertEqual(self.flag_lines(lines), [])

    def test_flag_skips_critical_and_flagged_plans(self):
        rc, lines, _ = self.curate({
            "2026-09-01-live.plan.md": plan(
                body="Enabler for docs/project/plans/2026-09-02-c.plan.md "
                     "and docs/project/plans/2026-09-03-f.plan.md"),
            "2026-09-02-c.plan.md": plan(risk="critical",
                                         accepted="2026-09-02T00:00:00Z"),
            "2026-09-03-f.plan.md": (
                "<!-- plan: status=accepted risk=normal priority=high "
                "accepted=2026-09-03T00:00:00Z -->\n# already flagged\n\n"
                "## Steps\n\n- [ ] 1. step 1\n"),
        })
        flags = "".join(self.flag_lines(lines))
        self.assertNotIn("2026-09-02-c", flags)
        self.assertNotIn("2026-09-03-f", flags)

    def test_flag_skips_plans_with_landed_steps(self):
        rc, lines, _ = self.curate({
            "2026-09-01-live.plan.md": plan(
                body="Enabler for docs/project/plans/2026-09-02-w.plan.md"),
            "2026-09-02-w.plan.md": plan(accepted="2026-09-02T00:00:00Z",
                                         steps=3, done=2),
        })
        self.assertEqual(self.flag_lines(lines), [])

    def test_merge_parks_older_duplicate_carrier(self):
        rc, lines, _ = self.curate({
            "2026-09-03-dup-old.plan.md": plan(routed="tree-skew:hngh",
                                               accepted="2026-09-03T00:00:00Z"),
            "2026-09-04-dup-new.plan.md": plan(routed="tree-skew:hngh",
                                               accepted="2026-09-04T00:00:00Z"),
        })
        self.assertEqual(rc, 0)
        parks = [l for l in lines if l.startswith("needs\t")]
        self.assertEqual(len(parks), 1)
        self.assertIn("2026-09-03-dup-old", parks[0])
        self.assertIn("cause=duplicate", parks[0])
        self.assertIn("disposed=", parks[0])
        self.assertIn("2026-09-04-dup-new", parks[0])

    def test_merge_leaves_newest_carrier_live(self):
        rc, lines, _ = self.curate({
            "2026-09-03-dup-old.plan.md": plan(routed="tree-skew:hngh",
                                               accepted="2026-09-03T00:00:00Z"),
            "2026-09-04-dup-new.plan.md": plan(routed="tree-skew:hngh",
                                               accepted="2026-09-04T00:00:00Z"),
        })
        parks = "".join(l for l in lines if l.startswith("needs\t"))
        self.assertNotIn("2026-09-04-dup-new", parks.replace(
            "newest carrier 2026-09-04-dup-new", ""))

    def test_merge_skips_critical_and_landed_carriers(self):
        rc, lines, _ = self.curate({
            "2026-09-01-crit-old.plan.md": plan(
                risk="critical", routed="id:crit", steps=2,
                accepted="2026-09-01T00:00:00Z"),
            "2026-09-02-crit-new.plan.md": plan(
                routed="id:crit", accepted="2026-09-02T00:00:00Z"),
            "2026-09-03-landed-old.plan.md": plan(
                routed="id:land", steps=3, done=2,
                accepted="2026-09-03T00:00:00Z"),
            "2026-09-04-landed-new.plan.md": plan(
                routed="id:land", accepted="2026-09-04T00:00:00Z"),
        })
        self.assertEqual([l for l in lines if l.startswith("needs\t")], [])

    def test_merge_never_parks_parked_plans(self):
        # a parked plan is not an accepted carrier: nothing to merge
        rc, lines, _ = self.curate({
            "2026-09-03-parked.plan.md": plan(status="parked",
                                              cause="obsolete",
                                              routed="id:p",
                                              accepted="2026-09-03T00:00:00Z"),
        })
        self.assertEqual(rc, 0)
        parks = "".join(l for l in lines if l.startswith("needs\t"))
        self.assertNotIn("2026-09-03-parked", parks)

    def test_handoff_flags_deck_node_plans_as_report_verb(self):
        rc, lines, _ = self.curate({
            "2026-09-01-deck.plan.md": plan(
                body="Runs the research beat on the deck node "
                     "per DECK-NODE.md Phase 3."),
        })
        handoffs = [l for l in lines if l.startswith("flagged\t")
                    and "deck" in l]
        self.assertEqual(len(handoffs), 1)
        self.assertIn("2026-09-01-deck", handoffs[0])

    def test_staging_edges_listed_and_targets_exist(self):
        rc, lines, home = self.curate({
            "2026-09-01-live.plan.md": plan(
                body="This plan is the enabler for "
                     "docs/project/plans/2026-09-02-integration.plan.md"),
            "2026-09-02-integration.plan.md": plan(
                accepted="2026-09-02T00:00:00Z"),
        })
        edges = [l for l in lines if l.startswith("needs\t")
                 and "staging" in l]
        self.assertEqual(len(edges), 1)
        self.assertIn("2026-09-01-live", edges[0])
        self.assertIn("2026-09-02-integration", edges[0])

    def test_proposals_reference_only_existing_plans(self):
        texts = {
            "2026-09-01-live.plan.md": plan(
                body="Enabler for docs/project/plans/2026-09-09-ghost.plan.md "
                     "and the deck node per DECK-NODE.md."),
        }
        rc, lines, _ = self.curate(texts)
        existing = set(texts)
        self.assertNotIn("2026-09-09-ghost", "\n".join(lines))
        for l in lines:
            for tok in l.split("\t", 1)[1].split():
                tok = tok.strip(",;()")
                if tok.endswith(".plan.md"):
                    self.assertIn(tok, existing, l)

    def test_no_op_tree_emits_nothing(self):
        rc, lines, _ = self.curate({
            "2026-09-01-solo.plan.md": plan(),
            "2026-09-02-done.plan.md": plan(status="executed", steps=2,
                                            done=2,
                                            accepted="2026-09-02T00:00:00Z"),
        })
        self.assertEqual(rc, 0)
        self.assertEqual(lines, [])

    def test_day_wrapper_files_operator_items_without_plan_changes(self):
        with tempfile.TemporaryDirectory() as td:
            home = Path(td) / "kernel"
            plans_dir = home / "docs" / "project" / "plans"
            plans_dir.mkdir(parents=True)
            texts = {
                "2026-09-01-live.plan.md": plan(
                    body="Enabler for "
                         "docs/project/plans/2026-09-02-integration.plan.md"),
                "2026-09-02-integration.plan.md": plan(
                    accepted="2026-09-02T00:00:00Z"),
            }
            for name, text in texts.items():
                (plans_dir / name).write_text(text)
            before = {p.name: p.read_bytes() for p in plans_dir.iterdir()}
            db = Path(td) / "crumbs.db"
            out = Path(td) / "plans.json"
            env = {**os.environ, "HNGH_HOME": str(home),
                   "HNGH_PLANS_FEED_OUT": str(out), "HNGH_CRUMBS_DB": str(db),
                   "HNGH_CEREMONY_LOG": ""}
            r = subprocess.run([sys.executable, str(PLAN_FEED)], env=env,
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            r = subprocess.run(["bash", str(WRAPPER)], env=env,
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            rows = crumbs_export(db)
            self.assertTrue(any("| flagged |" in x for x in rows), rows)
            self.assertTrue(any("| needs |" in x for x in rows), rows)
            after = {p.name: p.read_bytes() for p in plans_dir.iterdir()}
            self.assertEqual(before, after)
            n = len(rows)
            r = subprocess.run(["bash", str(WRAPPER)], env=env,
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertEqual(len(crumbs_export(db)), n)

    def test_day_wrapper_dedup_ignores_disposed_timestamp(self):
        """Same proposal re-emitted by a later daily beat must dedup
        against yesterday's row even though the embedded disposed=
        timestamp differs (the 2026-09-20 daily re-filing defect)."""
        with tempfile.TemporaryDirectory() as td:
            home = Path(td) / "kernel"
            plans_dir = home / "docs" / "project" / "plans"
            plans_dir.mkdir(parents=True)
            (plans_dir / "2026-09-03-dup-old.plan.md").write_text(
                plan(routed="tree-skew:hngh", accepted="2026-09-03T00:00:00Z"))
            (plans_dir / "2026-09-04-dup-new.plan.md").write_text(
                plan(routed="tree-skew:hngh", accepted="2026-09-04T00:00:00Z"))
            db = Path(td) / "crumbs.db"
            out = Path(td) / "plans.json"
            env = {**os.environ, "HNGH_HOME": str(home),
                   "HNGH_PLANS_FEED_OUT": str(out), "HNGH_CRUMBS_DB": str(db),
                   "HNGH_CEREMONY_LOG": ""}
            r = subprocess.run([sys.executable, str(PLAN_FEED)], env=env,
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            r = subprocess.run(["bash", str(WRAPPER)], env=env,
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            rows = crumbs_export(db)
            self.assertTrue(any("| needs |" in x for x in rows))
            self.assertTrue(any("cause=duplicate" in x and "disposed=" in x
                                for x in rows))
            # Restamp every filed row to yesterday: identical proposal
            # text, different disposed= timestamp. The restamped lines
            # reload through the journal importer (stamp round-trips
            # into the writer column).
            restamped = [re.sub(r" disposed=[^ ]*Z ",
                                " disposed=2026-09-19T00:00:00Z ", x)
                         for x in rows]
            fixture = Path(td) / "restamped.md"
            fixture.write_text("\n".join(restamped) + "\n")
            for suffix in ("", "-wal", "-shm"):
                p = Path(str(db) + suffix)
                if p.exists():
                    p.unlink()
            r = subprocess.run([sys.executable, str(CRUMBS_DB_PY), "sync",
                                "--state", str(fixture), "--db", str(db)],
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            n = len(crumbs_export(db))
            r = subprocess.run(["bash", str(WRAPPER)], env=env,
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertEqual(len(crumbs_export(db)), n)


if __name__ == "__main__":
    unittest.main()
