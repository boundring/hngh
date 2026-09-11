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
       "context-pack.sh", "launch-session.sh", "model-demote.sh")

DRIVER = """#!/usr/bin/env bash
set -u
. "$AUTO_ROOT/lib/common.sh"
. "$AUTO_ROOT/lib/launch-session.sh"
launch_session tslug tobject "$PROMPT"
printf 'rc=%s log=%s cause=%s\\n' "$LAUNCH_RC" "$LAUNCH_LOG" "$LAUNCH_CAUSE"
"""

OC_STUB = """#!/usr/bin/env bash
printf 'opencode %s config=%s\\n' "$*" "$OPENCODE_CONFIG" >> "$OC_MARKER"
printf 'keylen=%s\\n' "${#OPENCODE_API_KEY}" >> "$OC_MARKER"
if [ -n "${OC_FAIL:-}" ]; then
 TS=$(date +%s)000
 printf '{"type":"text","timestamp":%s,"sessionID":"ses_fail","part":{"type":"text","text":"error: timeout exceeded while integrating"}}\\n' "$TS"
 exit 1
fi
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
        # the hngh config layer: the OPENCODE_CONFIG target + agent prompts
        shutil.copytree(AUTO / "config" / "opencode",
                        self.auto / "config" / "opencode")
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
        # hermetic credential: when the environment carries no real
        # OPENCODE_API_KEY (env -i), the tests supply a fake 600 key file
        # — the value never leaves this temp dir
        self.keyfile = self.td / "test-env-key"
        self.keyfile.write_text("x" * 32)
        self.keyfile.chmod(0o600)
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
        if "OPENCODE_API_KEY" not in os.environ:
            e["OPENCODE_KEY_FILE"] = str(self.keyfile)
        e.update(extra)
        # None values mean "unset this var" (credential-fallback tests)
        return {k: v for k, v in e.items() if v is not None}

    def launch(self, **extra):
        return subprocess.run(["bash", str(self.driver)], env=self.env(**extra),
                              capture_output=True, text=True, timeout=60)

    def test_opencode_branch_launches_with_safety_config(self):
        r = self.launch(HNGH_SESSION_EXECUTOR="opencode")
        self.assertEqual(r.returncode, 0, r.stderr)
        marker = self.oc_marker.read_text()
        self.assertIn("--auto", marker)
        self.assertIn("--agent executor", marker)
        self.assertIn("-m opencode-go/glm-5.3-flash", marker)
        self.assertIn("config=" + str(self.auto / "config"
                                      / "opencode" / "opencode.jsonc"), marker)
        # the key rode through to the child (never its value; length only)
        env_len = len(os.environ.get("OPENCODE_API_KEY", ""))
        if env_len:
            self.assertIn("keylen=%d" % env_len, marker)
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
        # self-steering loop, happy-path skip: clean rc=0 exit classified
        # unknown matched no failure keyword — no lesson line (pollution fix)
        self.assertFalse((self.auto / "state"
                          / "ocgo-agent-lessons.md").exists())
        # demote counter fires for the opencode branch keyed to the model
        # actually used (not the omp SESSION_MODEL) — the gap fix
        demote = (self.auto / "state" / "model-demote.tsv").read_text()
        self.assertIn("opencode-go/glm-5.3-flash\t0\t0", demote)

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

    def test_no_credential_falls_back_to_omp(self):
        # fail-closed: neither env key nor a 600 key file -> omp
        r = self.launch(HNGH_SESSION_EXECUTOR="opencode",
                        OPENCODE_API_KEY=None,
                        OPENCODE_KEY_FILE=str(self.td / "no-such-key"))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(self.oc_marker.exists())
        self.assertIn("-p --model", self.omp_marker.read_text())

    def test_failed_session_appends_lesson(self):
        # a real failure (rc!=0, keyword-classified) lands its lesson line
        r = self.launch(HNGH_SESSION_EXECUTOR="opencode", OC_FAIL="1")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("rc=1", r.stdout)
        lessons = (self.auto / "state" / "ocgo-agent-lessons.md").read_text()
        self.assertIn("| bad-execution |", lessons)
        self.assertIn("the step was too big", lessons)

    def test_key_file_fallback_wires_key_into_child(self):
        # no env key; the operator key file (mode 600) is wired into the
        # child env — length observable, value never printed anywhere
        kfile = self.td / "opencode-key"
        kfile.write_text("k" * 42)
        kfile.chmod(0o600)
        r = self.launch(HNGH_SESSION_EXECUTOR="opencode",
                        OPENCODE_API_KEY=None,
                        OPENCODE_KEY_FILE=str(kfile))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("keylen=42", self.oc_marker.read_text())

    def test_key_file_too_open_falls_back_to_omp(self):
        # mode 644 key file is refused (same trust pattern as model.sh)
        kfile = self.td / "opencode-key"
        kfile.write_text("k" * 42)
        kfile.chmod(0o644)
        r = self.launch(HNGH_SESSION_EXECUTOR="opencode",
                        OPENCODE_API_KEY=None,
                        OPENCODE_KEY_FILE=str(kfile))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(self.oc_marker.exists())


def _load_jsonc(path):
    """Parse JSONC (line comments) — string-aware, tiny, no dependency."""
    out = []
    for line in Path(path).read_text().splitlines():
        res, in_str, esc = [], False, False
        i = 0
        while i < len(line):
            c = line[i]
            if in_str:
                if esc:
                    esc = False
                elif c == "\\":
                    esc = True
                elif c == '"':
                    in_str = False
                res.append(c)
            elif c == '"':
                in_str = True
                res.append(c)
            elif c == "/" and line[i:i + 2] == "//":
                break
            else:
                res.append(c)
            i += 1
        out.append("".join(res))
    return json.loads("\n".join(out))


class OcgoConfigLayer(unittest.TestCase):
    """The config layer itself (real files): deny-block superset, MCP
    registrations, agent roles, model pin, lessons-loop instruction."""

    def test_deny_block_superset(self):
        base = _load_jsonc(AUTO / "config" / "opencode-safety.jsonc")
        cfg = _load_jsonc(AUTO / "config" / "opencode" / "opencode.jsonc")
        for k, v in base["permission"]["read"].items():
            self.assertEqual(cfg["permission"]["read"].get(k), v, k)

    def test_mcp_servers_registered(self):
        cfg = _load_jsonc(AUTO / "config" / "opencode" / "opencode.jsonc")
        mcp = cfg["mcp"]
        self.assertEqual(mcp["hngh"]["type"], "local")
        self.assertTrue(mcp["hngh"]["enabled"])
        self.assertIn("hngh_mcp_server.py", " ".join(mcp["hngh"]["command"]))
        # copied verbatim from the prior install (both verified present)
        self.assertIn("misakanet/scripts/mcp_server.py",
                      " ".join(mcp["misakanet"]["command"]))
        self.assertIn("codegraph", " ".join(mcp["codegraph"]["command"]))

    def test_agent_roles_and_model_pin(self):
        cfg = _load_jsonc(AUTO / "config" / "opencode" / "opencode.jsonc")
        agents = cfg["agent"]
        self.assertEqual(agents["executor"]["mode"], "primary")
        self.assertEqual(agents["hngh-scout"]["mode"], "subagent")
        # scout is read-only: edit/bash denied (tool restriction via
        # permission — the documented agent-format mechanism)
        self.assertEqual(agents["hngh-scout"]["permission"]["edit"], "deny")
        self.assertEqual(agents["hngh-scout"]["permission"]["bash"], "deny")
        # Go quota model pinned everywhere; small_model pinned too so
        # lightweight tasks never route to another model id
        pin = "opencode-go/glm-5.3-flash"
        self.assertEqual(cfg["model"], pin)
        self.assertEqual(cfg["small_model"], pin)
        self.assertEqual(agents["executor"]["model"], pin)
        self.assertEqual(agents["hngh-scout"]["model"], pin)
        self.assertEqual(cfg["default_agent"], "executor")
        # prior-install plugins stay OUT of the hngh config (decision:
        # they serve no hngh purpose; Go quota rides OPENCODE_API_KEY)
        self.assertNotIn("plugin", cfg)
        # the learning loop: both agent prompts read the lessons tail
        for role in ("executor", "scout"):
            prompt_file = AUTO / "config" / "opencode" / "agents" / (
                role + ".md")
            self.assertIn("ocgo-agent-lessons.md", prompt_file.read_text())

    def test_lessons_append_and_cap(self):
        import subprocess as sp
        self._td2 = tempfile.TemporaryDirectory()
        tmp = Path(self._td2.name)
        script = (
            "set -u\n"
            f"AUTOMATION_ROOT={tmp}\n"
            f". {AUTO}/lib/causes.sh\n"
            f". {AUTO}/lib/launch-session.sh\n"
            "for i in $(seq 1 205); do append_ocgo_lesson bad-execution; done\n"
            "grep -vc '^#' \"$AUTOMATION_ROOT/state/ocgo-agent-lessons.md\"\n"
            "head -n 6 \"$AUTOMATION_ROOT/state/ocgo-agent-lessons.md\"\n"
        )
        r = sp.run(["bash", "-c", script], capture_output=True, text=True,
                   timeout=120)
        self.assertEqual(r.returncode, 0, r.stderr)
        lines = r.stdout.strip().splitlines()
        self.assertEqual(lines[0], "200")  # capped at 200 entries
        self.assertIn("bad-execution", lines[-1])
        self.assertIn("the step was too big", lines[-1])
        self.assertTrue(lines[1].startswith("# ocgo-agent lessons"))

    def tearDown(self):
        if hasattr(self, "_td"):
            self._td.cleanup()
        if hasattr(self, "_td2"):
            self._td2.cleanup()


if __name__ == "__main__":
    unittest.main()
