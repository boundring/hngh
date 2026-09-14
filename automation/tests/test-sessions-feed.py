#!/usr/bin/env python3
"""sessions-feed per-CLI discovery (jcode/opencode/pi), hermetic.

Every machine-launched session lands in dashboard/sessions.json: jcode
session files + log "API call complete" tails, opencode SQLite sessions
+ log tails, pi JSONL transcripts parsed with the omp parser. Fixtures
are tempdirs wired through the module's env seams (JCODE_SESSIONS_DIR,
JCODE_LOG_DIR, OPENCODE_DATA_DIR, PI_SESSIONS_DIR); no real stores and
no live sessions are touched.
"""

import importlib.util
import itertools
import json
import os
import sqlite3
import tempfile
import time
import unittest
from pathlib import Path

AUTO = Path(__file__).resolve().parent.parent
FEED = AUTO / "jobs" / "sessions-feed.py"

_names = itertools.count()


def load_feed(**env):
    """Fresh module instance with the store dirs pointed at env."""
    os.environ.update({k: str(v) for k, v in env.items()})
    spec = importlib.util.spec_from_file_location(
        "sessions_feed_%d" % next(_names), FEED)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def jcode_session(path, sid, title=None, messages=None, age_s=0,
                  workdir="/repo/x"):
    now = time.time()
    s = {
        "id": sid,
        "title": title,
        "created_at": time.strftime("%Y-%m-%dT%H:%M:%S",
                                    time.gmtime(now - age_s)) + ".0Z",
        "updated_at": time.strftime("%Y-%m-%dT%H:%M:%S",
                                    time.gmtime(now)) + ".0Z",
        "messages": messages or [],
        "model": "glm-5.3-flash",
        "provider_key": "openai-compatible:zai",
        "working_dir": workdir,
        "last_pid": 4242,
    }
    Path(path).write_text(json.dumps(s))
    os.utime(path, (now - age_s, now - age_s))


class JcodeRows(unittest.TestCase):
    def test_live_row_with_log_tail_and_mission(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (root / "sessions").mkdir()
            (root / "logs").mkdir()
            sid = "session_owl_1789346093422_abc"
            jcode_session(root / "sessions" / (sid + ".json"),
                          sid, title=None, workdir="/home/u/proj", age_s=10,
                          messages=[
                              {"role": "user", "content":
                               "<system-reminder>ctx</system-reminder>"},
                              {"role": "user", "content": "ship the lane"},
                          ])
            log = root / "logs" / "jcode-2026-09-14.log"
            # real jcode log tags carry only the id's first 20 chars
            log.write_text(
                "pre [ses:other|x] API call complete in 1s\n"
                "[ses:%s|prv:zai|mod:glm] API call complete in 2.5s "
                "(input=7 output=3)\n"
                "[ses:%s|prv:zai|mod:glm] API call complete in 9s\n"
                % (sid[:20], sid[:20]))
            sf = load_feed(JCODE_SESSIONS_DIR=root / "sessions",
                           JCODE_LOG_DIR=root / "logs")
            rows = sf.jcode_rows(time.time())
            self.assertEqual(len(rows), 1)
            r = rows[0]
            self.assertEqual(r["id"], sid)
            self.assertEqual(r["state"], "live")
            self.assertEqual(r["source"], "jcode/proj")
            self.assertEqual(r["model"], "glm-5.3-flash")
            self.assertEqual(r["pid"], 4242)
            self.assertEqual(r["mission"], "ship the lane")
            self.assertIn("API call complete in 9s", r["detail"]["tail"])
            self.assertNotIn("ses:other", r["detail"]["tail"])

    def test_stale_session_beyond_window_excluded(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (root / "sessions").mkdir()
            (root / "logs").mkdir()
            jcode_session(root / "sessions" / "session_old_1_x.json",
                          "session_old_1_x", age_s=25 * 3600)
            sf = load_feed(JCODE_SESSIONS_DIR=root / "sessions",
                           JCODE_LOG_DIR=root / "logs")
            self.assertEqual(sf.jcode_rows(time.time()), [])


class OpencodeRows(unittest.TestCase):
    def test_live_row_model_id_and_window(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            (root / "log").mkdir()
            now_ms = int(time.time() * 1000)
            db = root / "opencode.db"
            con = sqlite3.connect(db)
            con.execute("CREATE TABLE session (id TEXT PRIMARY KEY,"
                        " directory TEXT, title TEXT, model TEXT,"
                        " cost REAL, time_created INTEGER,"
                        " time_updated INTEGER)")
            con.execute("INSERT INTO session VALUES (?,?,?,?,?,?,?)",
                        ("ses_live1", "/home/u/hngh", "fix the gantt",
                         '{"id":"glm-5.3-flash","providerID":"zai"}', 0.5,
                         now_ms - 60_000, now_ms - 10_000))
            con.execute("INSERT INTO session VALUES (?,?,?,?,?,?,?)",
                        ("ses_old1", "/home/u/hngh", "ancient", None, 0.0,
                         now_ms - 25 * 3600_000, now_ms - 25 * 3600_000))
            con.commit()
            con.close()
            (root / "log" / "opencode.log").write_text(
                "level=INFO session.id=ses_live1 message=process started\n")
            sf = load_feed(OPENCODE_DATA_DIR=root)
            rows = sf.opencode_rows(time.time())
            self.assertEqual([r["id"] for r in rows], ["ses_live1"])
            r = rows[0]
            self.assertEqual(r["state"], "live")
            self.assertEqual(r["source"], "opencode/hngh")
            self.assertEqual(r["model"], "glm-5.3-flash")
            self.assertEqual(r["mission"], "fix the gantt")
            self.assertIn("ses_live1", r["detail"]["tail"])

    def test_missing_db_yields_no_rows(self):
        with tempfile.TemporaryDirectory() as td:
            sf = load_feed(OPENCODE_DATA_DIR=td)
            self.assertEqual(sf.opencode_rows(time.time()), [])


class PiRows(unittest.TestCase):
    def test_omp_shaped_jsonl_parses_to_entries(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            d = root / "--home-u-proj"
            d.mkdir()
            now = time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime()) + ".000Z"
            (d / "2026-09-14T00-00-00-000Z_uuid.jsonl").write_text("\n".join([
                '{"type":"session","version":3,"id":"p1","timestamp":"%s",'
                '"cwd":"/x"}' % now,
                '{"type":"message","id":"a","timestamp":"%s","message":'
                '{"role":"user","content":[{"type":"text","text":'
                '"list the tools"}]}}' % now,
            ]) + "\n")
            sf = load_feed(PI_SESSIONS_DIR=root)
            rows = sf.pi_rows(time.time())
            self.assertEqual(len(rows), 1)
            r = rows[0]
            self.assertTrue(r["id"].startswith("pi-"))
            self.assertEqual(r["state"], "live")
            # omp_candidates lstrips the escaped-path leading dashes
            self.assertEqual(r["source"], "pi/home-u-proj")
            self.assertEqual(r["mission"], "list the tools")
            self.assertEqual(r["detail"]["counts"]["user"], 1)


class FeedWiring(unittest.TestCase):
    def test_main_includes_all_cli_rows_and_fail_open(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            empty = root / "empty"
            empty.mkdir()
            (root / "sessions").mkdir()
            (root / "logs").mkdir()
            jcode_session(root / "sessions" / "session_elk_1_x.json",
                          "session_elk_1_x", title="wiring")
            sf = load_feed(JCODE_SESSIONS_DIR=root / "sessions",
                           JCODE_LOG_DIR=root / "logs",
                           OPENCODE_DATA_DIR=empty,
                           PI_SESSIONS_DIR=empty,
                           OMP_BRIDGE_STORE=empty)
            sf.OMP_SESSIONS = str(empty)  # keep real omp store out
            sf.READOUT = str(root / "readout.json")
            sf.OUT = str(root / "sessions.json")
            (root / "readout.json").write_text('{"roster": []}')
            sf.main()
            feed = json.loads((root / "sessions.json").read_text())
            self.assertIn("session_elk_1_x",
                          [r["id"] for r in feed["sessions"]])
            # missing readout keeps the prior feed (fail-open contract)
            (root / "readout.json").unlink()
            sf.main()
            self.assertTrue((root / "sessions.json").exists())


if __name__ == "__main__":
    unittest.main()
