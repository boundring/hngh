#!/usr/bin/env python3
"""agent-supervision session_exit grounding, hermetic (no real sessions,
no real report-queue). The 2026-09-04 defect: omp-impl-phase3-9d5ab9
EXITED (session_exit event, after a 7m-hung tool call) yet kept filing
daily "stalled (awaiting-operator)" alerts — the classifier never read
the exit marker. Contract now: a transcript whose FINAL line is a
session_exit event is terminal — never stalled, never re-alerted; the
roguelike replace path stays bridge-only (parked separately)."""

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


class SupervisionExit(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.root = Path(self._td.name)
        self.sessions = self.root / "sessions"
        self.sessions.mkdir()
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
        for name in ("rq-stub", "hngh-stub", "bridge-stub"):
            p = self.root / name
            p.write_text(
                "#!%s\nimport os, sys\n"
                "open(os.environ['RQ_LOG'], 'a').write("
                "' '.join(sys.argv[1:]) + '\\n')\n" % sys.executable)
            p.chmod(0o755)
        self.rq_log = self.root / "rq.log"
        self.state = self.root / "state.json"
        self.env = {
            **os.environ,
            "SUPERVISION_SOURCES": str(self.sessions),
            "SUPERVISION_STATE": str(self.state),
            "SUPERVISION_REPORT_QUEUE": str(self.root / "rq-stub"),
            "OMP_BRIDGE_STORE": str(self.root / "bridge"),  # empty: no runs
            "HNGH_BIN": str(self.root / "hngh-stub"),
            "OMP_BRIDGE_BIN": str(self.root / "bridge-stub"),
            "RQ_LOG": str(self.rq_log),
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

    def test_scan_transcript_exit_flag(self):
        spec = importlib.util.spec_from_file_location(
            "agent_supervision", str(SUP))
        sup = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(sup)
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


if __name__ == "__main__":
    unittest.main()