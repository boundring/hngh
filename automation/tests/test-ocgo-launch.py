#!/usr/bin/env python3
"""opencode executor launch branch, hermetic (no real sessions, no spend).

launch_session picks the child command from one cadence-params row
(session-executor; empty/absent = omp fail-closed; HNGH_SESSION_EXECUTOR
overrides). executor=opencode runs `opencode run --dir --format json -m
opencode-go/<model> --auto` with OPENCODE_CONFIG pinned to the copied
secret-deny block (automation/config/opencode-safety.jsonc), then the R2
emitter attributes agent-internal spend and extracts plain text into the
classifier's log path. Bridge lifecycle, budget row, log path and
disposition spine are unchanged (design 2026-09-10 s5). Binaries are
stubbed — nothing real is ever launched.
"""

import json
import os
import shutil
import sqlite3
import subprocess
import tempfile
import unittest
from pathlib import Path

AUTO = Path(__file__).resolve().parent.parent

LIB = ("common.sh", "breadcrumbs.sh", "causes.sh", "params.sh",
       "context-pack.sh", "launch-session.sh")

DRIVER = """#!/usr/bin/env bash
set -u
. "$AUTO_ROOT/lib/common.sh"
. "$AUTO_ROOT/lib/launch-session.sh"
launch_session tslug tobject "$PROMPT"
printf 'rc=%s log=%s cause=%s\\n' "$LAUNCH_RC" "$LAUNCH_LOG" "$LAUNCH_CAUSE"
"""

OC_STUB = """#!/usr/bin/env bash
printf 'opencode %s config=%s\\n' "$*" "$OPENCODE_CONFIG" >> "$OC_MARKER"
cat <<'JSON'
{"type":"step_finish","timestamp":TIMESTAMP,"sessionID":"ses_test1","part":{"type":"step-finish","tokens":{"input":31495,"output":93},"cost":0.003}}
{"type":"text","timestamp":TIMESTAMP,"sessionID":"ses_test1","part":{"type":"text","text":"done\\nrationale: finished"}}
JSON
"""


class OcgoLaunch(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.td = Path(self._td.name)
        self.auto = self.td / "automation"
        (self.auto / "lib").mkdir(parents=True)
        (self.auto / "config").mkdir()
        (self.auto / "jobs").mkdir()
        (self.auto / "logs").mkdir()
        for f in LIB:
            shutil.copy(AUTO / "lib" / f, self.auto / "lib" / f)
        shutil.copy(AUTO / "config" / "opencode-safety.jsonc",
                    self.auto / "config" / "opencode-safety.jsonc")
        shutil.copy(AUTO / "jobs" / "ocgo-attribution.py",
                    self.auto / "jobs" / "ocgo-attribution.py")
        # the emitter reuses jobs/telemetry.py's write path (never a
        # second schema) — the sandbox must carry it too
        shutil.copy(AUTO / "jobs" / "telemetry.py",
                    self.auto / "jobs" / "telemetry.py")
        self.telem = self.td / "telemetry.db"
        (self.auto / "cadence-params.tsv").write_text(
            "# Inventory\n"
            "session-executor\t\ttest\tempty = omp fail-closed\n"
            "opencode-model\tglm-5.3-flash\ttest\ttest row\n")
        self.kernel = self.td / "kernel"
        self.kernel.mkdir()
        self.prompt = self.kernel / "prompt.txt"
        self.prompt.write_text("do the thing\n")
        self.oc_marker = self.td / "oc.marker"
        self.omp_marker = self.td / "omp.marker"
        self.bridge = self.td / "bridge-stub.sh"
        self.bridge.write_text('echo "run run-42 started $*"\n')
        self.omp = self.td / "omp"
        self.omp.write_text('printf "%s\\n" "$*" >> "$OMP_MARKER"\nexit 0\n')
        stubs = self.td / "stubs"
        stubs.mkdir()
        self.oc = stubs / "opencode"
        self.oc.write_text(OC_STUB.replace("TIMESTAMP",
                                           str(int(self.td.stat().st_mtime)
                                               * 1000)))
        for f in (self.bridge, self.omp, self.oc):
            f.chmod(0o755)
        self.driver = self.td / "driver.sh"
        self.driver.write_text(DRIVER)
        self.driver.chmod(0o755)

    def tearDown(self):
        self._td.cleanup()

    def env(self, **extra):
        e = dict(os.environ,
                 AUTO_ROOT=str(self.auto),
                 PROMPT=str(self.prompt),
                 ROOT=str(self.kernel),
                 STORE=str(self.td / "store"),
                 TIMEOUT_S="10",
                 SESSION_MODEL="zai/glm-5.3",
                 OC_MARKER=str(self.oc_marker),
                 OMP_MARKER=str(self.omp_marker),
                 OMP_BRIDGE_BIN=str(self.bridge),
                 OMP_BIN_CMD=str(self.omp),
                 HNGH_TELEMETRY_DB=str(self.telem),
                 PATH=str(self.td / "stubs") + ":" + os.environ["PATH"])
        e.update(extra)
        return e

    def launch(self, **extra):
        return subprocess.run(["bash", str(self.driver)], env=self.env(**extra),
                              capture_output=True, text=True, timeout=60)

    def test_opencode_branch_launches_with_safety_config(self):
        r = self.launch(HNGH_SESSION_EXECUTOR="opencode")
        self.assertEqual(r.returncode, 0, r.stderr)
        marker = self.oc_marker.read_text()
        self.assertIn("--auto", marker)
        self.assertIn("-m opencode-go/glm-5.3-flash", marker)
        self.assertIn("config=" + str(self.auto / "config"
                                      / "opencode-safety.jsonc"), marker)
        self.assertNotIn("-p --model",
                         self.omp_marker.read_text() if
                         self.omp_marker.exists() else "")
        # plain text landed at the classifier's log path; json on the side
        import re
        run_id = r.stdout.strip().splitlines()[-1]
        log = self.kernel / re.search(r"log=(\S+)", run_id).group(1)
        self.assertIn("finished", log.read_text())
        self.assertTrue((Path(str(log) + ".json"))
                        .exists())
        # R2: the emitter attributed agent-internal spend
        conn = sqlite3.connect(self.telem)
        row = conn.execute("select source, kind, identity, tokens_in,"
                           " tokens_out, cost_usd from events").fetchall()
        conn.close()
        self.assertEqual(row, [("ocgo-agent", "model", "ses_test1",
                                31495, 93, 0.003)])

    def test_default_executor_is_omp(self):
        r = self.launch()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("-p --model", self.omp_marker.read_text())
        self.assertFalse(self.oc_marker.exists())

    def test_opencode_unavailable_falls_back_to_omp(self):
        # model row emptied: fail-closed fallback with a breadcrumb
        (self.auto / "cadence-params.tsv").write_text(
            "# Inventory\nsession-executor\topencode\ttest\tarmed\n")
        r = self.launch(HNGH_SESSION_EXECUTOR="opencode",
                        PATH=str(self.td / "stubs") + ":" + os.environ["PATH"])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("-p --model", self.omp_marker.read_text())


if __name__ == "__main__":
    unittest.main()
