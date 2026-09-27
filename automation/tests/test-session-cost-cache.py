#!/usr/bin/env python3
"""Governed-fleet slice B: tokens_cached backfill across legs.

The omp transcript leg (jobs/session-cost.py parse_transcript) must sum
usage.cacheRead (the read-side cache-hit counter) into the emitted row's
tokens_cached. Write side (cacheWrite) is never a cached hit. This
complements test-slice-a-bili-surface.sh (model.sh legs) and the
test-ocgo-launch.py emitter test (opencode stream leg): every leg that
reports a cached shape lands it on the same schema (jobs/telemetry.py
telemetry.db), never a second table.
"""

import importlib.util
import json
import os
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JOB = ROOT / "jobs" / "session-cost.py"


def _load():
    spec = importlib.util.spec_from_file_location("session_cost_cache", JOB)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)  # sessions_feed import side must run
    return mod


CACHE_LINE = json.dumps({
    "type": "message", "id": "m1",
    "message": {
        "model": "zai/glm-5.3-flash",
        "usage": {"input": 100, "output": 10, "cacheRead": 77,
                  "cacheWrite": 5,
                  "cost": {"total": 0.002}},
    },
    "timestamp": 1789000000000,
}) + "\n" + json.dumps({
    "type": "session", "id": "ses-cache-1", "timestamp": 1789000000001,
}) + "\n"


class SessionCostCacheBackfill(unittest.TestCase):
    def test_cacheRead_sums_into_tokens_cached(self):
        with tempfile.TemporaryDirectory() as td:
            tr = Path(td) / "tr.jsonl"
            tr.write_text(CACHE_LINE)
            mod = _load()
            sid, models, tin, tout, tokc, cost, first, last, usage = \
                mod.parse_transcript(str(tr))
            self.assertEqual(sid, "ses-cache-1")
            self.assertEqual((tin, tout), (100, 10))
            self.assertEqual(tokc, 77)  # read side only; cacheWrite=5 excluded
            self.assertEqual(models, {"zai/glm-5.3-flash": 1})
            self.assertEqual(cost, 0.002)

    def test_no_cache_field_backfills_to_zero(self):
        with tempfile.TemporaryDirectory() as td:
            tr = Path(td) / "tr.jsonl"
            tr.write_text(json.dumps({
                "type": "message", "id": "m2",
                "message": {"model": "m",
                            "usage": {"input": 1, "output": 1,
                                      "cost": {"total": 0}}},
                "timestamp": 1789000000002,
            }) + "\n")
            mod = _load()
            _, _, _, _, tokc, _, _, _, _ = mod.parse_transcript(str(tr))
            self.assertEqual(tokc, 0)


if __name__ == "__main__":
    unittest.main()
