#!/usr/bin/env python3
"""agent-supervision tests — hermetic (no real sessions, no real
report-queue). Two contracts:

1. session_exit grounding (the 2026-09-04 defect): a transcript whose
   FINAL line is a session_exit event is terminal — never stalled,
   never re-alerted.
2. The P4 folded supervision plane (2026-09-25, agent-watchdog.sh and
   beat-watchdog.py retired into this module): active / slow-valid /
   stalled steer-once-then-die evidence machine, ported loop +
   hard-error detections, bridge-run roguelike replace with cause= from
   lib/causes.sh, and the overnight-lead beat rules over crumbs +
   handoffs. All via SUPERVISION_* env seams and stub binaries."""

import hashlib
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SUP = ROOT / "jobs" / "agent-supervision.py"


def tool_line(ts):
    return json.dumps({"type": "message", "toolCall": {}, "timestamp": ts},
                      separators=(",", ":"))


def asst_line(ts, text):
    return json.dumps({"type": "message", "role": "assistant",
                       "timestamp": ts,
                       "parts": [{"type": "text", "text": text}]},
                      separators=(",", ":"))


def exit_line(ts):
    return json.dumps({"type": "custom", "customType": "session_exit",
                       "timestamp": ts}, separators=(",", ":"))


def iso(ago_s):
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() - ago_s))


class SupervisionBase(unittest.TestCase):
    """Hermetic env: sandbox sessions dir + stub rq/hngh/bridge binaries
    logging argv to RQ_LOG; params file absent -> code defaults."""

    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name)
        self.sessions = self.root / "sessions"
        self.sessions.mkdir()
        for name in ("rq-stub", "hngh-stub", "bridge-stub"):
            p = self.root / name
            p.write_text(
                "#!%s\nimport os, sys\n"
                "open(os.environ['RQ_LOG'], 'a').write("
                "' '.join(sys.argv[1:]) + '\\n')\n" % sys.executable)
            p.chmod(0o755)
        self.rq_log = self.root / "rq.log"
        self.state = self.root / "state.json"
        self.handoffs = self.root / "agent-handoffs.md"
        self.handoffs.touch()
        self.blockers = self.root / "state" / "beat-blockers.tsv"
        self.blockers.parent.mkdir()
        self.blockers.touch()
        self.params = self.root / "cadence-params.tsv"  # absent -> defaults
        self.crumbs_db = self.root / "state" / "crumbs.db"
        self.env = {
            **os.environ,
            "SUPERVISION_SOURCES": str(self.sessions),
            "SUPERVISION_STATE": str(self.state),
            "SUPERVISION_REPORT_QUEUE": str(self.root / "rq-stub"),
            "OMP_BRIDGE_STORE": str(self.root / "bridge"),  # empty: no runs
            "HNGH_BIN": str(self.root / "hngh-stub"),
            "OMP_BRIDGE_BIN": str(self.root / "bridge-stub"),
            "RQ_LOG": str(self.rq_log),
            "SUPERVISION_HANDOFFS": str(self.handoffs),
            "SUPERVISION_BLOCKERS": str(self.blockers),
            "SUPERVISION_PARAMS": str(self.params),
            "HNGH_CRUMBS_DB": str(self.crumbs_db),
            "SUPERVISION_CAUSES_SH": str(CAUSES_SH),
        }

    def tearDown(self):
        self._td.cleanup()

    def sid(self, path):
        stem = Path(path).stem
        return "omp-%s-%s" % (stem[:28],
                              hashlib.md5(str(path).encode()).hexdigest()[:6])

    def rows(self):
        return (self.rq_log.read_text().splitlines()
                if self.rq_log.exists() else [])

    def tick(self):
        return subprocess.run([sys.executable, str(SUP)], env=self.env,
                              capture_output=True, text=True, timeout=120)

    def module(self):
        spec = importlib.util.spec_from_file_location(
            "agent_supervision", str(SUP))
        sup = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(sup)
        return sup


CAUSES_SH = ROOT / "lib" / "causes.sh"
CRUMBS_DB_PY = ROOT / "lib" / "crumbs-db.py"


class SupervisionExit(SupervisionBase):
    def setUp(self):
        super().setUp()
        # exited: recent tool call, asks the operator, then session_exit —
        # the exact omp-impl-phase3-9d5ab9 shape that looped daily
        self.exited = self.sessions / "impl-phase3.jsonl"
        self.exited.write_text(
            tool_line(iso(30 * 60)) + "\n"
            + asst_line(iso(25 * 60), "shall i proceed with the push?") + "\n"
            + exit_line(iso(20 * 60)) + "\n")
        t = time.time() - 20 * 60
        os.utime(self.exited, (t, t))
        # control: same ask, same quiet, NO exit marker -> still stalls
        self.alive = self.sessions / "verify-phase2.jsonl"
        self.alive.write_text(
            tool_line(iso(40 * 60)) + "\n"
            + asst_line(iso(35 * 60), "shall i proceed with the push?") + "\n")
        os.utime(self.alive, (t, t))

    def test_scan_transcript_exit_flag(self):
        sup = self.module()
        stats = sup.scan_transcript(str(self.exited))
        self.assertTrue(stats["exited"])
        self.assertTrue(stats["asks"])  # asks alone no longer implies stalled
        alive = sup.scan_transcript(str(self.alive))
        self.assertFalse(alive["exited"])

    def test_exited_session_is_terminal_never_stalled(self):
        self.tick()  # tick 1: record priors
        self.tick()  # tick 2: classify with priors
        alert_rows = [r for r in self.rows() if "--add alert" in r]
        self.assertEqual([r for r in alert_rows
                          if self.sid(self.exited) in r], [],
                         "exited session must never stall-alert")
        self.assertTrue(any(self.sid(self.alive) in r
                            for r in alert_rows), self.rows())
        phase = json.loads(self.state.read_text())[
            self.sid(self.exited)]["last_phase"]
        self.assertEqual(phase, "terminal")


def tc_line(ts, name, arguments):
    """assistant toolCall turn — counts as a tool call and feeds the
    trailing-loop detection. Real omp record shape: the payload nests
    under "message" and tool calls live in "content"."""
    return json.dumps({"type": "message", "timestamp": ts,
                       "message": {"role": "assistant",
                                   "content": [{"type": "toolCall",
                                                "name": name,
                                                "arguments": arguments}]}},
                      separators=(",", ":"))


def tr_line(ts, text):
    return json.dumps({"type": "message", "timestamp": ts,
                       "message": {"role": "toolResult",
                                   "content": [{"type": "text",
                                                "text": text}]}},
                      separators=(",", ":"))


class SupervisionStates(SupervisionBase):
    """The evidence machine over one sandbox omp transcript: active is
    silent; slow-valid flags once, never kills; stalled steers once then
    dies (advisory for transcripts — no close-run, no kill)."""

    def write_session(self, name, body, mtime_ago_s):
        p = self.sessions / name
        p.write_text(body)
        t = time.time() - mtime_ago_s
        os.utime(p, (t, t))
        return p

    def test_active_session_is_silent(self):
        self.write_session(
            "active-one.jsonl",
            tc_line(iso(30), "read_file", {"path": "x"}) + "\n"
            + asst_line(iso(20), "reading the module now") + "\n", 10)
        self.tick()
        self.tick()
        self.assertEqual(self.rows(), [], "healthy ticks are silent")
        st = json.loads(self.state.read_text())[self.sid(
            self.sessions / "active-one.jsonl")]
        self.assertEqual(st["sup_state"], "active")
        self.assertEqual(st["misses"], 0)

    def test_slow_valid_flags_once_never_kills(self):
        p = self.write_session(
            "slow-valid-one.jsonl",
            tc_line(iso(25 * 60), "run_command", {"cmd": "make test"}) + "\n"
            + asst_line(iso(24 * 60), "suite running") + "\n", 60)
        self.tick()
        self.tick()  # fresh evidence, tool calls flat > 20m
        sid = self.sid(p)
        slow = [r for r in self.rows()
                if "supervision:%s:slow-valid" % sid in r]
        self.assertEqual(len(slow), 1, self.rows())
        self.assertEqual([r for r in self.rows() if "stalled" in r], [],
                         "slow-valid is never stalled")
        self.assertEqual(self.handoffs.read_text(), "",
                         "slow-valid never writes handoff rows")
        self.assertNotIn("close-run", self.rq_log.read_text())
        self.assertEqual(json.loads(self.state.read_text())[
            sid]["sup_state"], "slow-valid")

    def test_stalled_steers_once_then_dies(self):
        p = self.write_session(
            "stalled-one.jsonl",
            asst_line(iso(30 * 60), "thinking about the design") + "\n"
            + asst_line(iso(29 * 60), "still weighing options") + "\n",
            30 * 60)  # stale mtime: no evidence for > 2 ticks
        sid = self.sid(p)
        self.tick()  # tick 1: steer
        self.assertIn("stalled: steer:", self.handoffs.read_text())
        self.assertEqual(len([r for r in self.rows()
                              if "supervision:%s:stalled" % sid in r]), 1,
                         self.rows())
        self.assertNotIn("close-run", self.rq_log.read_text(),
                         "omp transcripts are advisory, never killed")
        self.tick()  # tick 2: die
        self.assertIn("dead: stalled past 2 ticks cause=unclassified",
                      self.handoffs.read_text())
        self.assertNotIn("close-run", self.rq_log.read_text())
        self.tick()  # tick 3: still dead — same identity bumps
        st = json.loads(self.state.read_text())[sid]
        self.assertEqual(st["misses"], 3)
        self.assertEqual(st["sup_state"], "stalled")
        self.assertEqual(len([r for r in self.rows()
                              if "supervision:%s:stalled" % sid in r]), 3)


class SupervisionBridgeDie(SupervisionBase):
    """Bridge runs keep the roguelike replace path on the second missed
    tick, with cause= classified from the record by lib/causes.sh."""

    def test_bridge_stall_replaced_with_cause(self):
        store = self.root / "bridge"
        store.mkdir()
        record = store / "record.lisp"
        record.write_text(
            '(:IDENTIFIER "run-9" :KIND :CREATION :STATE :CREATED '
            ':RUN (:IDENTIFIER "run-9" :MISSION (:OBJECTIVE '
            '"seeded bridge die") :STATE :CREATED) :RECEIPT '
            '(:KIND :CREATION :FACTS ("identifier: run-9" '
            '"timestamp: %s" "error: 404 not found")))\n' % iso(3600))
        self.tick()  # tick 1: steer
        self.assertIn("stalled: steer:", self.handoffs.read_text())
        self.assertNotIn("close-run", self.rq_log.read_text())
        self.tick()  # tick 2: die + replace
        log = self.rq_log.read_text()
        self.assertIn("close-run run-9 dead", log, log)
        self.assertEqual(log.count("--run-start"), 1, log)
        self.assertIn("auto-replace", log)
        self.assertIn("cause=missing-knowledge", self.handoffs.read_text(),
                      self.handoffs.read_text())
        self.assertFalse(record.exists(), "record rotated on replace")


class SupervisionDetections(SupervisionBase):
    """Ported watchdog detections: trailing identical-tool-call loop and
    uncorrected hard-error result (grace window)."""

    def test_loop_detection(self):
        sup = self.module()
        p = self.root / "loop.jsonl"
        p.write_text("\n".join(
            tc_line(iso(60 * i), "run_command", {"cmd": "flaky"})
            for i in range(3)) + "\n")
        self.assertIn("identical tool call x3: run_command",
                      sup.scan_transcript(str(p))["loop_sig"])
        p.write_text("\n".join(
            tc_line(iso(60 * i), "run_command", {"cmd": "flaky", "n": i})
            for i in range(3)) + "\n")
        self.assertIsNone(sup.scan_transcript(str(p))["loop_sig"])

    def test_error_result_detection(self):
        sup = self.module()
        err = "traceback: boom — the command failed"

        def scan(ago_s, text):
            p = self.root / "err.jsonl"
            p.write_text(tr_line(iso(ago_s), text) + "\n")
            return sup.scan_transcript(str(p))

        self.assertIn("hard error result", scan(5 * 60, err)["err_sig"])
        self.assertIsNone(scan(30, err)["err_sig"], "inside grace window")
        self.assertIsNone(scan(5 * 60, "all green")["err_sig"])


class SupervisionOvernightLead(SupervisionBase):
    """Folded beat-watchdog rule: beat silence — newest overnight-done
    crumb stale past beat-stall-silence-hours (default 12) while cadence
    ticks kept arriving — files one blocker row + one alert, once."""

    def test_beat_silence_files_blocker_once(self):
        fixture = self.root / "crumbs-state.md"
        fixture.write_text(
            "%s | overnight-cycle.sh | overnight-done | results=ok\n"
            "%s | cadence-10m | mounted | tier beat\n"
            % (iso(13 * 3600), iso(120)))
        p = subprocess.run(
            [sys.executable, str(CRUMBS_DB_PY), "sync",
             "--state", str(fixture), "--db", str(self.crumbs_db)],
            capture_output=True, text=True, timeout=60)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.tick()
        self.tick()  # blocker exists now: rule stays silent
        self.assertEqual(len([r for r in self.rows()
                              if "supervision:overnight-lead:silence" in r]),
                         1, self.rows())
        rows = self.blockers.read_text().splitlines()
        self.assertEqual(len(rows), 1, rows)
        cols = rows[0].split("\t")
        self.assertEqual(len(cols), 6, rows[0])
        self.assertEqual(cols[1], "overnight-silence", rows[0])
        self.assertEqual(cols[2], "bad-execution", rows[0])
        self.assertEqual(cols[5], "parked", rows[0])


if __name__ == "__main__":
    unittest.main()