#!/usr/bin/env python3
"""test-ghost-voices.py — hermetic tests for lib/ghost-voices.py
(course-correction slice 4). Stubs the bridge; never calls a model."""

import importlib.util
import os
import sys
import tempfile
import time
import unittest

AUTO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD = os.path.join(AUTO, "lib", "ghost-voices.py")


def load_mod():
    spec = importlib.util.spec_from_file_location("ghost_voices", MOD)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class GhostVoicesTest(unittest.TestCase):
    def setUp(self):
        self.td = tempfile.mkdtemp(prefix="ghost-test-")
        self.state = os.path.join(self.td, "ghost-state")
        self.stub = os.path.join(self.td, "stub.txt")
        os.environ["HNGH_GHOST_STATE"] = self.state
        os.environ.pop("HNGH_GHOST_TSV", None)
        os.environ.pop("HNGH_XIAOMI_CMD", None)
        with open(self.stub, "w") as fh:
            fh.write("  Keep the\n ledger honest, operator.\n")
        os.environ["HNGH_GHOST_STUB"] = self.stub
        self.gv = load_mod()

    def tearDown(self):
        for k in ("HNGH_GHOST_STATE", "HNGH_GHOST_STUB",
                  "HNGH_GHOST_TSV", "HNGH_XIAOMI_CMD"):
            os.environ.pop(k, None)

    def stamp(self, age_s=0):
        os.makedirs(self.state, exist_ok=True)
        fp = os.path.join(self.state, "s%d" % time.monotonic_ns())
        open(fp, "w").close()
        past = time.time() - age_s
        os.utime(fp, (past, past))

    def test_roster_loads_full_pantheon(self):
        ghosts = self.gv.load_ghosts()
        self.assertEqual(len(ghosts), 39)
        for g in ghosts:
            self.assertTrue(g["name"] and g["era"] and g["register"]
                            and g["convictions"])
        names = {g["name"] for g in ghosts}
        for want in ("George Orwell", "Franz Kafka", "Stanisław Lem",
                     "Ludwig Wittgenstein"):
            self.assertIn(want, names)

    def test_pick_deterministic_distinct(self):
        ghosts = self.gv.load_ghosts()
        a = [g["name"] for g in self.gv.pick_ghosts(ghosts, "2026-09-27-0")]
        b = [g["name"] for g in self.gv.pick_ghosts(ghosts, "2026-09-27-0")]
        self.assertEqual(a, b)
        self.assertEqual(len(a), 3)
        self.assertEqual(len(set(a)), 3)

    def test_cap_blocks_at_six_fresh(self):
        for _ in range(6):
            self.stamp()
        self.assertIsNone(self.gv.ghost_counsel())
        self.assertEqual(len(os.listdir(self.state)), 6)

    def test_cap_ignores_old_stamps(self):
        for _ in range(6):
            self.stamp(age_s=self.gv.CAP_WINDOW_S + 3600)
        line = self.gv.ghost_counsel()
        self.assertEqual(line, "Keep the ledger honest, operator.")
        fresh = [f for f in os.listdir(self.state)
                 if time.time() - os.path.getmtime(
                     os.path.join(self.state, f)) < self.gv.CAP_WINDOW_S]
        self.assertEqual(len(fresh), 1)

    def test_bridge_failure_fail_closed(self):
        os.environ.pop("HNGH_GHOST_STUB", None)
        os.environ["HNGH_XIAOMI_CMD"] = "exit 7"
        self.assertIsNone(self.gv.ghost_counsel())
        self.assertEqual(os.listdir(self.state), [])

    def test_empty_answer_fail_closed(self):
        open(self.stub, "w").close()
        self.assertIsNone(self.gv.ghost_counsel())
        self.assertEqual(os.listdir(self.state), [])


GOOD = ("The machine keeps a ledger of its own appetites and the "
        "operator should read it slowly, because every row is a small "
        "confession written by an automated hand that never sleeps.")


class GhostSummariesTest(unittest.TestCase):
    """ghost_summaries: batched prompt, strict parse, cache, cap, and
    the LOUD quiet contract (breadcrumb + reason) on empty outcomes."""

    def setUp(self):
        self.td = tempfile.mkdtemp(prefix="ghost-sum-")
        self.state = os.path.join(self.td, "ghost-state")
        self.stub = os.path.join(self.td, "stub.txt")
        self.cache = os.path.join(self.td, "ghost-summaries.json")
        os.environ["HNGH_GHOST_STATE"] = self.state
        os.environ["HNGH_GHOST_SUMMARIES"] = self.cache
        os.environ["HNGH_GHOST_PARAMS"] = os.path.join(
            self.td, "no-params.tsv")
        os.environ["HNGH_REPORT_IDENTITIES"] = os.path.join(
            self.td, "report-identities.json")
        for k in ("HNGH_GHOST_TSV", "HNGH_XIAOMI_CMD",
                  "HNGH_GHOST_CAP_DAY"):
            os.environ.pop(k, None)
        with open(self.stub, "w") as fh:
            fh.write("GHOST|id-1|George Orwell|%s\n" % GOOD)
        os.environ["HNGH_GHOST_STUB"] = self.stub
        self.gv = load_mod()
        import report_queue
        self._rq = report_queue
        self._orig_report = report_queue.report
        self.breadcrumbs = []
        report_queue.report = self._fake_report

    def _fake_report(self, *args, **kwargs):
        self.breadcrumbs.append((args, kwargs))
        return True

    def tearDown(self):
        self._rq.report = self._orig_report
        for k in ("HNGH_GHOST_STATE", "HNGH_GHOST_STUB",
                  "HNGH_GHOST_SUMMARIES", "HNGH_GHOST_PARAMS",
                  "HNGH_REPORT_IDENTITIES", "HNGH_GHOST_TSV",
                  "HNGH_XIAOMI_CMD", "HNGH_GHOST_CAP_DAY"):
            os.environ.pop(k, None)

    def arts(self):
        return [{"id": "id-%d" % i, "headline": "Headline %d" % i,
                 "deck": "Deck %d." % i, "category": "world"}
                for i in (1, 2, 3)]

    def stamp_count(self):
        return len(os.listdir(self.state)) if os.path.isdir(self.state) \
            else 0

    def test_strict_parse_keeps_good_rows(self):
        with open(self.stub, "w") as fh:
            fh.write(
                "GHOST|id-1|George Orwell|%s\n"
                "not a structured ghost line at all\n"
                "GHOST|id-unknown|George Orwell|%s\n"
                "GHOST|id-2|Nobody McFake|%s\n"
                "GHOST|id-2|George Orwell|the stale row mentions stale "
                "machine state and keeps adding words right here to "
                "pass the twenty word floor for summaries\n"
                "GHOST|id-3|George Orwell|too short\n"
                "GHOST|id-3|George Orwell|%s\n"
                % (GOOD, GOOD, GOOD, GOOD))
        got, quiet = self.gv.ghost_summaries(self.arts(), "stamp-a")
        self.assertIsNone(quiet)
        self.assertEqual(sorted(got), ["id-1", "id-3"])
        self.assertEqual(got["id-1"],
                         {"voice": "George Orwell", "text": GOOD})
        self.assertEqual(self.breadcrumbs, [])
        self.assertTrue(os.path.exists(self.cache))  # cached
        self.assertEqual(self.stamp_count(), 1)      # budget stamped

    def test_cache_serves_and_skips_calls(self):
        got1, q1 = self.gv.ghost_summaries(self.arts(), "stamp-a")
        self.assertEqual(sorted(got1), ["id-1"])
        with open(self.stub, "w") as fh:
            fh.write("garbage stub: cannot produce any id\n")
        got2, q2 = self.gv.ghost_summaries(self.arts(), "stamp-b")
        self.assertEqual(got2["id-1"]["text"], GOOD)  # served from cache
        # the fresh half of the call produced nothing -> loud lib-side
        # reason; compose still suppresses the marker (a ghost renders)
        self.assertEqual(q2, "all ghost summaries malformed")
        self.assertEqual(self.stamp_count(), 2)  # one call per run
        got3, q3 = self.gv.ghost_summaries(
            [self.arts()[0]], "stamp-c")  # everything cached
        self.assertEqual(got3["id-1"]["text"], GOOD)
        self.assertEqual(self.stamp_count(), 2)  # no third call

    def test_cap_blocks_loudly(self):
        os.makedirs(self.state, exist_ok=True)
        for i in range(12):
            open(os.path.join(self.state, "s%d" % i), "w").close()
        got, quiet = self.gv.ghost_summaries(self.arts(), "stamp-a")
        self.assertEqual(got, {})
        self.assertEqual(quiet, "ghost cap exhausted (12 in 24h)")
        self.assertEqual(len(self.breadcrumbs), 1)
        _, kwargs = self.breadcrumbs[0]
        self.assertEqual(kwargs.get("identity"), "ghost-desk-quiet")
        self.assertEqual(kwargs.get("window"), 86400)
        self.assertEqual(self.stamp_count(), 12)  # stub not consumed

    def test_bridge_failure_loud(self):
        os.environ.pop("HNGH_GHOST_STUB", None)
        os.environ["HNGH_XIAOMI_CMD"] = "exit 7"
        got, quiet = self.gv.ghost_summaries(self.arts(), "stamp-a")
        self.assertEqual(got, {})
        self.assertEqual(quiet, "xiaomi bridge failed (rc 7)")
        self.assertEqual(len(self.breadcrumbs), 1)
        self.assertFalse(os.path.exists(self.cache))
        self.assertEqual(self.stamp_count(), 0)

    def test_all_malformed_loud(self):
        with open(self.stub, "w") as fh:
            fh.write("GHOST|ghost rows missing below|broken\n")
        got, quiet = self.gv.ghost_summaries(self.arts(), "stamp-a")
        self.assertEqual(got, {})
        self.assertEqual(quiet, "all ghost summaries malformed")
        self.assertEqual(len(self.breadcrumbs), 1)
        self.assertFalse(os.path.exists(self.cache))
        self.assertEqual(self.stamp_count(), 1)  # the call still cost

    def test_rosterless_loud(self):
        empty = os.path.join(self.td, "empty.tsv")
        open(empty, "w").close()
        os.environ["HNGH_GHOST_TSV"] = empty
        got, quiet = self.gv.ghost_summaries(self.arts(), "stamp-a")
        self.assertEqual(got, {})
        self.assertEqual(quiet, "no ghost roster")
        self.assertEqual(len(self.breadcrumbs), 1)
        self.assertEqual(self.stamp_count(), 0)


if __name__ == "__main__":
    unittest.main()
