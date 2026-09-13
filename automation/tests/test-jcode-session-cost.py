#!/usr/bin/env python3
"""Fixture tests for jobs/jcode-session-cost.py (jcode log -> telemetry)."""

import json
import importlib.util
import os
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JOB = ROOT / "jobs" / "jcode-session-cost.py"
TELEMETRY = ROOT / "jobs" / "telemetry.py"

SID_A = "session_alpha_1789000000001_aaa111"
SID_B = "session_beta_1789000000002_bbb222"
SID_C = "session_gamma_1789000000003_ccc333"

OLD_LOG = "\n".join([
    f"[2026-09-13 10:00:00.100] [INFO] ENV_SNAPSHOT "
    f'{{"captured_at":"2026-09-13T10:00:00Z","reason":"create",'
    f'"session_id":"{SID_A}","working_dir":"/home/bricker/Projects/proj-alpha",'
    f'"provider":"zai","model":"glm-5.3-flash","jcode_version":"v0.84.0"}}',
    f"[2026-09-13 10:00:01.000] [INFO] [ses:{SID_A}|prv:zai|mod:glm-5.3-flash] "
    f"API call complete in 3.20s (input=1000 output=50 cache_read=0 cache_write=0)",
    f"[2026-09-13 10:05:30.500] [INFO] [ses:{SID_A}|prv:zai|mod:glm-5.3-flash] "
    f"API call complete in 12.00s (input=6731 output=59 cache_read=0 cache_write=0)",
    f"[2026-09-13 10:06:00.000] [INFO] [ses:{SID_B}|prv:unsloth|mod:unsloth/Qwen3.8-27B-GGUF] "
    f"API call complete in 1.00s (input=0 output=0 cache_read=0 cache_write=0)",
    "not a log line at all",
    "",
])

FRESH_LOG = "\n".join([
    f"[2026-09-13 17:59:00.000] [INFO] [ses:{SID_C}|prv:zai|mod:glm-5.3-flash] "
    f"API call complete in 2.00s (input=10 output=5 cache_read=0 cache_write=0)",
    "",
])


def _write(p: Path, text: str):
    p.write_text(text)
    return p


def _load_job():
    spec = importlib.util.spec_from_file_location(
        "jcode_session_cost", JOB)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class JcodeSessionCostTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        logdir = Path(self.tmp.name) / "logs"
        logdir.mkdir()
        self.old_log = _write(logdir / "jcode-2026-09-12.log", OLD_LOG)
        self.fresh_log = _write(logdir / "jcode-2026-09-13.log", FRESH_LOG)
        old = time.time() - 7200
        os.utime(self.old_log, (old, old))
        home = Path(self.tmp.name) / "hngh"
        (home / "db").mkdir(parents=True)
        self.home = home
        # _load_job() reads seams at import time: export them process-wide.
        self._saved_env = {k: os.environ.get(k) for k in
                           ("JCODE_LOG_DIR", "HNGH_HOME_DIR")}
        os.environ["JCODE_LOG_DIR"] = str(logdir)
        os.environ["HNGH_HOME_DIR"] = str(home)
        self.addCleanup(self._restore_env)
        self.env = dict(os.environ,
                        JCODE_LOG_DIR=str(logdir),
                        HNGH_HOME_DIR=str(home))

    def _restore_env(self):
        for k, v in self._saved_env.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v

    def _run(self, *args):
        return subprocess.run([sys.executable, str(JOB), *args],
                              env=self.env, capture_output=True, text=True)

    def test_parse_logs_groups_sessions(self):
        job = _load_job()
        sessions = job.parse_logs([self.old_log])
        self.assertIn(SID_A, sessions)
        self.assertEqual(sessions[SID_A]["tokens_in"], 7731)
        self.assertEqual(sessions[SID_A]["tokens_out"], 109)
        self.assertEqual(sessions[SID_A]["models"], {"glm-5.3-flash": 2})
        self.assertEqual(sessions[SID_A]["working_dir"],
                         "/home/bricker/Projects/proj-alpha")
        self.assertAlmostEqual(sessions[SID_A]["last"] - sessions[SID_A]["first"],
                               329.0, places=1)
        # zero-token calls still create the session but add nothing
        self.assertIn(SID_B, sessions)
        self.assertEqual(sessions[SID_B]["tokens_in"], 0)

    def test_fresh_log_deferred(self):
        job = _load_job()
        ready, fresh = job.discover_logs()
        self.assertEqual([p.name for p in ready], ["jcode-2026-09-12.log"])
        self.assertEqual([p.name for p in fresh], ["jcode-2026-09-13.log"])

    def test_dry_run_emits_ready_sessions_only(self):
        r = self._run("--dry-run")
        self.assertEqual(r.returncode, 0, r.stderr)
        rows = [json.loads(l) for l in r.stdout.splitlines()
                if l.startswith("{")]
        self.assertEqual([r_["identity"] for r_ in rows], [SID_A])
        self.assertEqual(rows[0]["subject"], "proj-alpha")
        self.assertEqual(rows[0]["model"], "glm-5.3-flash")
        self.assertEqual(rows[0]["data"]["tokens_in"], 7731)
        self.assertIn("deferred-live 1", r.stdout)
        self.assertIn("already-captured 0", r.stdout)

    def test_idempotent_against_telemetry_db(self):
        data = json.dumps({"tokens_in": 1, "tokens_out": 1, "cost_usd": 0.0})
        seed = subprocess.run(
            [sys.executable, str(TELEMETRY), "emit", "--kind", "session-cost",
             "--source", "jcode", "--identity", SID_A, "--subject", "proj-alpha",
             "--model", "glm-5.3-flash", "--wall-s", "1", "--data", data],
            env=self.env, capture_output=True, text=True)
        self.assertEqual(seed.returncode, 0, seed.stderr)
        r = self._run("--dry-run")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertNotIn(SID_A, r.stdout)
        self.assertIn("already-captured 1", r.stdout)
        self.assertIn("emitted 0", r.stdout)


if __name__ == "__main__":
    unittest.main()
