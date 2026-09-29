#!/usr/bin/env python3
"""parked-care contract: jobs/parked-care.py reads the report queue's
parked rows and emits one `needs` TSV row per kin cluster (2+ parked
rows sharing a [a-z0-9]{4,} token, park* tokens excluded), so the
disposition sweep sees combined debt instead of scattered singles.
Read-only: the queue itself is never mutated. Fail-closed: broken or
absent queue yields no rows, exit 0. The cadence wrapper is exercised
end to end with HNGH_CRUMBS_DB seams: one crumb per cluster, repeat
runs deduped."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JOB = ROOT / "jobs" / "parked-care.py"
WRAPPER = ROOT / "cadence" / "calendar" / "daily" / "12-parked-care.sh"
CRUMBS_DB_PY = ROOT / "lib" / "crumbs-db.py"


def crumbs_export(db):
    r = subprocess.run([sys.executable, str(CRUMBS_DB_PY), "export",
                        "--db", str(db)], capture_output=True, text=True)
    return r.stdout.splitlines()


def stub_queue(sb, payload):
    """A fake report-queue that prints `payload` on --json."""
    rq = sb / "rq"
    rq.write_text("#!/usr/bin/env bash\n"
                  "if [ \"$1\" = \"--json\" ]; then\n"
                  "  cat %s/qu.json\n"
                  "fi\n" % json.dumps(str(sb)))
    (sb / "qu.json").write_text(payload)
    rq.chmod(0o755)
    return rq


def run_job(sb, extra=None):
    env = {**os.environ,
           "HNGH_REPORT_QUEUE": str(sb / "rq"),
           "HNGH_REPORT_ROOT": str(sb)}
    env.update(extra or {})
    r = subprocess.run([sys.executable, str(JOB)], env=env,
                       capture_output=True, text=True)
    return r.returncode, r.stdout.splitlines()


def rows(*firsts):
    return json.dumps({"reports": [
        {"id": "r%d" % i, "ts": "2026-09-29T10:0%d:00Z" % i,
         "first": f} for i, f in enumerate(firsts)]})


class ParkedCare(unittest.TestCase):
    def care(self, payload):
        with tempfile.TemporaryDirectory() as td:
            sb = Path(td)
            stub_queue(sb, payload)
            return run_job(sb)

    def test_kin_cluster_emits_one_combined_row(self):
        rc, out = self.care(rows(
            "parked: transient-env keyring gap in deploy lane",
            "unrelated: manga pipeline output counts drifted",
            "parked: transient-env env var leaks into digest"))
        self.assertEqual(rc, 0)
        self.assertEqual(len(out), 1)
        self.assertTrue(out[0].startswith("needs\t"))
        self.assertIn("r0", out[0])
        self.assertIn("r2", out[0])
        self.assertIn("transient-env", out[0])
        self.assertNotIn("r1", out[0])

    def test_shared_park_word_alone_never_clusters(self):
        rc, out = self.care(rows(
            "parked: alpha pipeline debt",
            "parked: beta keyring debt"))
        self.assertEqual(rc, 0)
        self.assertEqual(out, [])

    def test_class_match_alone_never_clusters(self):
        # related = shared keyword token; card-class kin (the composer's
        # digest affordance) is too weak to combine debt on.
        rc, out = self.care(rows(
            "parked: alpha zeta-qux debt",
            "parked: beta gamma-quux keyring"))
        self.assertEqual(rc, 0)
        self.assertEqual(out, [])

    def test_uniform_emitter_rows_combine(self):
        # 6 rows sharing "research line" (df 6, inside the rarity band)
        # are one combine-worthy group, not six scattered crumbs.
        payload = rows(*["parked: research line row %d" % i
                         for i in range(6)])
        rc, out = self.care(payload)
        self.assertEqual(rc, 0)
        self.assertEqual(len(out), 1)
        self.assertTrue(out[0].startswith("needs\tparked-kin "))
        for i in range(6):
            self.assertIn("r%d" % i, out[0])

    def test_token_groups_bounded_by_rarity_band(self):
        # Per-token groups, no transitive closure: aaagroup (df 4) and
        # bbbgroup (df 8) each define their own group; bridge rows join
        # both; nothing exceeds the band, nothing blobs.
        firsts = ["parked: research line row %d" % i for i in range(6)]
        firsts += ["parked: aaagroup row %d" % i for i in range(4)]
        firsts += ["parked: bbbgroup row %d" % i for i in range(6)]
        for i in (8, 9, 10, 11):
            firsts[i] = "parked: aaagroup bbbgroup row %d" % i
        rc, out = self.care(rows(*firsts))
        self.assertEqual(rc, 0)
        self.assertEqual(len(out), 3)
        agg = " ".join(out)
        self.assertNotIn("parked-mass", agg)
        self.assertIn("r6+r7+r8+r9", agg)   # aaagroup group of 4
        self.assertIn("r15", agg)           # bbbgroup group of 8

    def test_midfrequency_vocabulary_is_not_kin(self):
        # 10 rows share "routerplan": df 10 is past the rarity band
        # (df 2..8) -> emitter boilerplate, never a chain.
        payload = rows(*["parked: routerplan case %d" % i
                         for i in range(10)])
        rc, out = self.care(payload)
        self.assertEqual(rc, 0)
        self.assertEqual(out, [])

    def test_timestamp_fragments_are_not_kin(self):
        # "15t17" (ISO fragment), "2070c5" (hex tail), "210z" (ms
        # fragment): digits mark a pointer, never a relation.
        rc, out = self.care(rows(
            "parked: alpha stall seen 15t17 2070c5 210z",
            "parked: beta drift done 15t17 2070c5 210z"))
        self.assertEqual(rc, 0)
        self.assertEqual(out, [])

    def test_empty_queue_and_broken_queue_fail_closed(self):
        self.assertEqual(self.care(json.dumps({"reports": []})), (0, []))
        with tempfile.TemporaryDirectory() as td:
            sb = Path(td)
            (sb / "rq").write_text("#!/usr/bin/env bash\nexit 3\n")
            (sb / "rq").chmod(0o755)
            self.assertEqual(run_job(sb), (0, []))
        with tempfile.TemporaryDirectory() as td:
            sb = Path(td)
            stub_queue(sb, "{not json")
            self.assertEqual(run_job(sb), (0, []))

    def test_output_deterministic(self):
        payload = rows(
            "parked: transient-env keyring gap",
            "parked: transient-env env leak",
            "parked: transient-env tty stall")
        first = self.care(payload)
        second = self.care(payload)
        self.assertEqual(first, second)
        self.assertEqual(len(first[1]), 1)

    def test_wrapper_files_crumb_once_and_dedups(self):
        with tempfile.TemporaryDirectory() as td:
            sb = Path(td)
            stub_queue(sb, rows(
                "parked: transient-env keyring gap",
                "parked: transient-env env leak"))
            db = sb / "crumbs.db"
            env = {**os.environ,
                   "HNGH_REPORT_QUEUE": str(sb / "rq"),
                   "HNGH_REPORT_ROOT": str(sb),
                   "HNGH_CRUMBS_DB": str(db)}
            r = subprocess.run(["bash", str(WRAPPER)], env=env,
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            first = [ln for ln in crumbs_export(db)
                     if "transient-env" in ln]
            self.assertEqual(len(first), 1)
            r = subprocess.run(["bash", str(WRAPPER)], env=env,
                               capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            again = [ln for ln in crumbs_export(db)
                     if "transient-env" in ln]
            self.assertEqual(len(again), 1)


if __name__ == "__main__":
    unittest.main()
