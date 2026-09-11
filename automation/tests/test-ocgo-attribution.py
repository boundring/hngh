#!/usr/bin/env python3
"""ocgo-attribution — hermetic R2 attribution tests (no auth, no spend).

The emitter (jobs/ocgo-attribution.py) turns opencode's local attribution
surface (--format json event stream, opencode.db as fallback) into the
same telemetry rows the ocgo HTTP leg emits — kind=model, source=ocgo-agent
— so quota_pace_blocked_5h sees agent-internal spend on the shared $12/5h
bucket. Fixture db copies the real message-table schema (measured example:
docs/research/2026-09-10-opencode-agentic-surface.md s2). Keyed by the
session ids the launcher captured: sessions it did not launch emit nothing.
"""

import json
import sqlite3
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

AUTO = Path(__file__).resolve().parent.parent
EMITTER = AUTO / "jobs" / "ocgo-attribution.py"

NOW_MS = int(time.time() * 1000)
FRESH = NOW_MS - 60_000
STALE = NOW_MS - 6 * 3600 * 1000

MESSAGE_SCHEMA = """CREATE TABLE message(
 id text PRIMARY KEY, session_id text NOT NULL,
 time_created integer NOT NULL, time_updated integer NOT NULL,
 data text NOT NULL)"""


def msg(mid, sid, created, cost, tin, tout, provider="opencode-go",
        model="glm-5.3-flash"):
    return (mid, sid, created, created, json.dumps({
        "role": "assistant", "cost": cost,
        "tokens": {"input": tin, "output": tout},
        "modelID": model, "providerID": provider,
        "time": {"created": created, "completed": created + 5000}}))


def step_finish(sid, ts, cost, tin, tout, text="ok"):
    return json.dumps({"type": "step_finish", "timestamp": ts, "sessionID": sid,
                       "part": {"type": "step-finish",
                                "tokens": {"input": tin, "output": tout},
                                "cost": cost}})


class OcgoAttribution(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.td = Path(self._td.name)
        self.ocdb = self.td / "opencode.db"
        conn = sqlite3.connect(self.ocdb)
        conn.execute(MESSAGE_SCHEMA)
        conn.executemany("INSERT INTO message VALUES(?,?,?,?,?)", [
            # ses_fresh: fresh, real spend — must be attributed
            msg("m1", "ses_fresh", FRESH, 0.003717945, 8019, 217),
            msg("m2", "ses_fresh", FRESH + 1000, 0.001, 100, 50),
            # ses_stale: spend older than the 5h pacer window — never emitted
            msg("m3", "ses_stale", STALE, 0.5, 999, 999),
        ])
        conn.commit()
        conn.close()
        self.stream = self.td / "events.jsonl"
        self.stream.write_text("\n".join([
            step_finish("ses_fresh", FRESH, 0.003717945, 8019, 217),
            step_finish("ses_fresh", FRESH + 1000, 0.001, 100, 50),
            # ses_dbonly: stream carries only the session id, no spend rows
            # — the emitter falls back to the fixture db for it
            json.dumps({"type": "text", "timestamp": FRESH,
                        "sessionID": "ses_dbonly"}),
            json.dumps({"type": "text", "timestamp": FRESH,
                        "sessionID": "ses_stranger", "part":
                        {"type": "text", "text": "not ours"}}),
        ]))
        self.telem = self.td / "telemetry.db"

    def tearDown(self):
        self._td.cleanup()

    def run_emitter(self, *extra):
        return subprocess.run(
            [sys.executable, "-B", str(EMITTER), str(self.stream),
             "--db", str(self.ocdb), "--telemetry", str(self.telem),
             *extra], capture_output=True, text=True, timeout=60)

    def rows(self):
        if not self.telem.exists():
            return []
        conn = sqlite3.connect(self.telem)
        out = conn.execute(
            "SELECT source, kind, identity, model, tokens_in, tokens_out,"
            " cost_usd FROM events WHERE kind='model'").fetchall()
        conn.close()
        return out

    def test_fresh_sessions_emitted_with_correct_fields(self):
        # db fallback path: fixture db holds ses_dbonly with spend
        conn = sqlite3.connect(self.ocdb)
        conn.executemany("INSERT INTO message VALUES(?,?,?,?,?)", [
            msg("m9", "ses_dbonly", FRESH, 0.01, 500, 60),
        ])
        conn.commit()
        conn.close()
        r = self.run_emitter()
        self.assertEqual(r.returncode, 0, r.stderr)
        rows = {x[2]: x for x in self.rows()}
        self.assertIn("ses_fresh", rows)
        self.assertEqual(rows["ses_fresh"][0], "ocgo-agent")
        self.assertEqual(rows["ses_fresh"][1], "model")
        self.assertEqual(rows["ses_fresh"][3], "opencode-go/glm-5.3-flash")
        self.assertEqual(rows["ses_fresh"][4], 8119)   # 8019 + 100
        self.assertEqual(rows["ses_fresh"][5], 267)    # 217 + 50
        self.assertAlmostEqual(rows["ses_fresh"][6], 0.004717945)
        self.assertIn("ses_dbonly", rows)              # db fallback
        self.assertEqual(rows["ses_dbonly"][4], 500)

    def test_stale_and_foreign_sessions_emit_nothing(self):
        r = self.run_emitter()
        self.assertEqual(r.returncode, 0, r.stderr)
        ids = {x[2] for x in self.rows()}
        self.assertNotIn("ses_stale", ids)   # outside the 5h pacer window
        self.assertNotIn("ses_stranger", ids)  # not a hngh-keyed session

    def test_rerun_is_idempotent(self):
        self.run_emitter()
        before = len(self.rows())
        self.run_emitter()
        self.assertEqual(len(self.rows()), before)

    def test_plain_text_extracted_for_classifier(self):
        self.stream.write_text(json.dumps({
            "type": "text", "timestamp": FRESH,
            "sessionID": "ses_fresh",
            "part": {"type": "text", "text": "done with cause=timeout"}}))
        plain = self.td / "plain.log"
        r = self.run_emitter("--plain", str(plain))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("cause=timeout", plain.read_text())


if __name__ == "__main__":
    unittest.main()
