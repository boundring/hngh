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
       "context-pack.sh", "launch-session.sh", "launch-jcode.sh",
       "model-demote.sh", "model.sh")

DRIVER = """#!/usr/bin/env bash
set -u
. "$AUTO_ROOT/lib/common.sh"
. "$AUTO_ROOT/lib/launch-session.sh"
launch_session tslug tobject "$PROMPT"
printf 'rc=%s log=%s cause=%s\\n' "$LAUNCH_RC" "$LAUNCH_LOG" "$LAUNCH_CAUSE"
"""

OC_STUB = """#!/usr/bin/env bash
printf 'opencode %s config=%s\\n' "$*" "$OPENCODE_CONFIG" >> "$OC_MARKER"
printf 'argv=%s\\n' "$*" >> "$OC_MARKER"
printf 'keylen=%s\\n' "${#OPENCODE_API_KEY}" >> "$OC_MARKER"
printf 'kimilen=%s\\n' "${#KIMI_API_KEY}" >> "$OC_MARKER"
printf 'zailen=%s\\n' "${#ZAI_API_KEY}" >> "$OC_MARKER"
printf 'proxy=%s\\n' "${HTTPS_PROXY:-}" >> "$OC_MARKER"
printf 'ca=%s\\n' "${NODE_EXTRA_CA_CERTS:-}" >> "$OC_MARKER"
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

# bili stub: `start` serves /__bili/health 200 on BILI_STUB_PORT (the
# launch path's health probe turns green and the wrap envs ride through)
BILI_STUB = """#!/usr/bin/env bash
exec python3 -c "
import os, http.server
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers(); self.wfile.write(b'ok')
    def log_message(self, *a): pass
http.server.HTTPServer(('127.0.0.1', int(os.environ['BILI_STUB_PORT'])), H).serve_forever()"
"""

# env stub: the e1 finding #3 red observable. The provider key VALUE
# never reaches the child's argv (env(1) strips assignments before
# exec), so the only argv surface the leak touches is env(1) itself
# (/proc/<pid>/cmdline for its pre-exec lifetime). The stub records its
# own argv verbatim, then emulates env(1)'s core contract (NAME=VALUE
# assignment words, -u NAME, -- separator) and execs the command so the
# oc stub still runs under it exactly like the real env binary.
ENV_STUB = """#!/usr/bin/env bash
printf 'envargv=%s\\n' "$*" >> "$ENV_MARKER"
while [ $# -gt 0 ]; do
  case "$1" in
    -u) unset "$2"; shift 2 ;;
    --) shift; break ;;
    [A-Za-z_]*=* | *_=*) export "$1"; shift ;;
    *) break ;;
  esac
done
exec "$@"
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
        self.env_marker = self.td / "env.marker"
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
        env_stub = stubs / "env"
        env_stub.write_text(ENV_STUB)
        for f in (self.bridge, self.omp, self.oc):
            f.chmod(0o755)
        env_stub.chmod(0o755)
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
                 ENV_MARKER=str(self.env_marker),
                 OMP_BRIDGE_BIN=str(self.bridge),
                 OMP_BIN_CMD=str(self.omp),
                 HNGH_TELEMETRY_DB=str(self.telem),
                 # ambient proxy envs (this process may itself ride a
                 # bili wrapper) would leak into the child marker
                 HTTPS_PROXY=None,
                 NODE_EXTRA_CA_CERTS=None,
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

    def test_kimi_provider_routes_kimi_quota(self):
        # OCGO_PROVIDER=kimi: the kimi-model row drives the model id, the
        # executor-kimi agent runs, the Kimi key rides ONLY as
        # KIMI_API_KEY (never OPENCODE_API_KEY), and the emitter
        # attributes source=kimi so the kimi daily pacer counts the call
        (self.auto / "cadence-params.tsv").write_text(
            "# Inventory\n"
            "session-executor\t\ttest\topencode via env override\n"
            "kimi-model\tk3-256k\ttest\ttest row\n")
        r = self.launch(HNGH_SESSION_EXECUTOR="opencode",
                        OCGO_PROVIDER="kimi", KIMI_AI_KEY="k" * 40,
                        OPENCODE_API_KEY=None)
        self.assertEqual(r.returncode, 0, r.stderr)
        marker = self.oc_marker.read_text()
        self.assertIn("--agent executor-kimi", marker)
        self.assertIn("-m kimi/k3-256k", marker)
        self.assertIn("kimilen=40", marker)
        self.assertIn("keylen=0", marker) # the OTHER quota's key never rides
        conn = sqlite3.connect(self.telem)
        row = conn.execute("select source, identity from events").fetchall()
        conn.close()
        self.assertEqual(row, [("kimi", "ses_test1")])

    def _seed_pacer_db(self, source, n):
        # every pacer reads $HNGH_TELEMETRY_DB (userspace-home seam); the
        # test env pins it to self.telem -- seed the SAME file
        return self._seed_pacer_db_at(source, n, "now")

    def _seed_pacer_db_at(self, source, n, ts_mod):
        # ts_mod: a strftime modifier (e.g. "-6 hours" = inside the 7d
        # window but outside the 5h window) for window-isolation tests
        ts_expr = ("strftime('%Y-%m-%dT%H:%M:%SZ','now')" if ts_mod == "now"
                   else f"strftime('%Y-%m-%dT%H:%M:%SZ','now','{ts_mod}')")
        db = sqlite3.connect(self.telem)
        db.execute(
            "CREATE TABLE IF NOT EXISTS events(ts TEXT, source TEXT,"
            " kind TEXT, identity TEXT, lane TEXT, unit TEXT, model TEXT,"
            " tokens_in INTEGER, tokens_out INTEGER, cost_usd REAL,"
            " wall_s REAL, subject TEXT, refs TEXT, body TEXT)")
        for _ in range(n):
            db.execute("INSERT INTO events(ts, source, kind)"
                       " VALUES (%s, ?, 'model')" % ts_expr, (source,))
        db.commit()
        db.close()

    def _seed_pacer_db_ts(self, source, n, iso_ts):
        # absolute-timestamp seeding (weekly fixed-window tests)
        db = sqlite3.connect(self.telem)
        db.execute(
            "CREATE TABLE IF NOT EXISTS events(ts TEXT, source TEXT,"
            " kind TEXT, identity TEXT, lane TEXT, unit TEXT, model TEXT,"
            " tokens_in INTEGER, tokens_out INTEGER, cost_usd REAL,"
            " wall_s REAL, subject TEXT, refs TEXT, body TEXT)")
        for _ in range(n):
            db.execute("INSERT INTO events(ts, source, kind)"
                       " VALUES (?, ?, 'model')", (iso_ts, source))
        db.commit()
        db.close()

    def test_jcode_zai_pacer_blocks_at_the_branch(self):
        # coexistence review gap #1 (2026-09-14): the jcode executor
        # branch rides the SAME zai subscription windows zai_chat spends.
        # Pacer blocked -> no jcode child (shim or CLI), omp fallback.
        self._seed_pacer_db("zai", 3)
        (self.auto / "cadence-params.tsv").write_text(
            "# Inventory\n"
            "session-executor\t\ttest\tempty = omp fail-closed\n"
            "jcode-provider\tzai\ttest\ttest row\n")
        r = self.launch(HNGH_SESSION_EXECUTOR="jcode",
                        ZAI_CAP_5H_CALLS="3")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(self.oc_marker.exists())
        self.assertIn("-p --model", self.omp_marker.read_text())

    def test_jcode_unsloth_provider_skips_the_zai_pacer(self):
        # unsloth rides the local box (no subscription windows): the
        # pacer must NOT block, and the jcode CLI leg must run (a jcode
        # stub on PATH marks it; no omp fallback for pacing reasons)
        (self.auto / "cadence-params.tsv").write_text(
            "# Inventory\n"
            "session-executor\t\ttest\tempty = omp fail-closed\n"
            "jcode-provider\tunsloth\ttest\ttest row\n")
        jc_stub = self.td / "stubs" / "jcode"
        jc_stub.write_text(
            'printf "jcode-cli %s\\n" "$*" >> "$OC_MARKER"\nexit 0\n')
        jc_stub.chmod(0o755)
        r = self.launch(HNGH_SESSION_EXECUTOR="jcode")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("jcode-cli run", self.oc_marker.read_text())
        self.assertFalse(self.omp_marker.exists())

    def test_opencode_go_5h_pacer_blocks_at_the_branch(self):
        # choke-point guarantee (quota-tightest-window-pacing): even a
        # direct launch_session caller cannot land an unpaced
        # opencode-go call -- 5h pacer blocked -> omp fallback, no
        # opencode child
        self._seed_pacer_db("ocgo", 3)
        r = self.launch(HNGH_SESSION_EXECUTOR="opencode",
                        OCGO_CAP_5H_CALLS="3")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(self.oc_marker.exists())
        self.assertIn("-p --model", self.omp_marker.read_text())

    def test_kimi_daily_pacer_blocks_at_the_branch(self):
        self._seed_pacer_db("kimi", 3)
        (self.auto / "cadence-params.tsv").write_text(
            "# Inventory\n"
            "session-executor\t\ttest\topencode via env override\n"
            "kimi-model\tk3-256k\ttest\ttest row\n")
        r = self.launch(HNGH_SESSION_EXECUTOR="opencode",
                        OCGO_PROVIDER="kimi", KIMI_AI_KEY="k" * 40,
                        OPENCODE_API_KEY=None, KIMI_DAILY_CAP_CALLS="3")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(self.oc_marker.exists())
        self.assertIn("-p --model", self.omp_marker.read_text())

    def test_7d_window_refuses_while_5h_has_headroom(self):
        # tightest-wins (quota-tightest-window-pacing): 5h sees zero but
        # the 7d window is exhausted -> refused to omp, no opencode child
        self._seed_pacer_db_at("ocgo", 150, "-6 hours")
        r = self.launch(HNGH_SESSION_EXECUTOR="opencode",
                        OCGO_CAP_7D_CALLS="150")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(self.oc_marker.exists())
        self.assertIn("-p --model", self.omp_marker.read_text())

    def test_month_window_refuses_while_5h_and_7d_have_headroom(self):
        self._seed_pacer_db_at("ocgo", 300, "-8 days")
        r = self.launch(HNGH_SESSION_EXECUTOR="opencode",
                        OCGO_CAP_MONTH_CALLS="300")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(self.oc_marker.exists())
        self.assertIn("-p --model", self.omp_marker.read_text())

    def test_zai_provider_routes_zai_quota(self):
        # OCGO_PROVIDER=zai: the zai-model row drives the model id, the
        # executor-zai agent runs, the subscription key rides ONLY as
        # ZAI_API_KEY, and the emitter attributes source=zai (the shared
        # bucket pair with the model.sh zai_chat leg)
        (self.auto / "cadence-params.tsv").write_text(
            "# Inventory\n"
            "session-executor\t\ttest\topencode via env override\n"
            "zai-model\tglm-5.3-flash\ttest\ttest row\n")
        r = self.launch(HNGH_SESSION_EXECUTOR="opencode",
                        OCGO_PROVIDER="zai", Z_AI_API_KEY="z" * 40,
                        OPENCODE_API_KEY=None)
        self.assertEqual(r.returncode, 0, r.stderr)
        marker = self.oc_marker.read_text()
        self.assertIn("--agent executor-zai", marker)
        self.assertIn("-m zai/glm-5.3-flash", marker)
        self.assertIn("zailen=40", marker)
        self.assertIn("keylen=0", marker) # the OTHER quota's key never rides
        conn = sqlite3.connect(self.telem)
        row = conn.execute("select source, identity from events").fetchall()
        conn.close()
        self.assertEqual(row, [("zai", "ses_test1")])

    def test_zai_weekly_window_refuses(self):
        # weekly is a FIXED window (Monday 00:00 UTC reset), gated beside
        # the 5h bucket: exhausted weekly -> refused to omp. Seeded 6h
        # into the running week (outside the 5h window once the week is
        # >= 11h old; earlier than that the 5h gate trips instead and the
        # assertions below still hold)
        import datetime
        now = datetime.datetime.now(datetime.timezone.utc)
        week_start = (now - datetime.timedelta(
            days=now.weekday())).replace(hour=0, minute=0, second=0,
                                         microsecond=0)
        seed_ts = (week_start + datetime.timedelta(hours=6)).strftime(
            "%Y-%m-%dT%H:%M:%SZ")
        self._seed_pacer_db_ts("zai", 3, seed_ts)
        r = self.launch(HNGH_SESSION_EXECUTOR="opencode",
                        OCGO_PROVIDER="zai", Z_AI_API_KEY="z" * 40,
                        OPENCODE_API_KEY=None, ZAI_CAP_WEEK_CALLS="3",
                        ZAI_CAP_5H_CALLS="500")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(self.oc_marker.exists())
        self.assertIn("-p --model", self.omp_marker.read_text())

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

    def _assert_key_never_on_argv(self, env_extra, key_name, key_value,
                                  marker_keylen):
        # e1 finding #3 (2026-09-16): the provider key VALUE must never
        # transit an argv. The child's own argv was never dirty (env(1)
        # strips assignments pre-exec), so the observable is env(1)'s
        # argv itself: the ENV_STUB on PATH records it verbatim. Red
        # under the old `env KEY=VALUE ...` spawn (the assignment word
        # carries the secret); green under the literal prefix assignment
        # (_spawn_with_key). The key must still REACH the child env
        # (marker_keylen) so the guard never breaks delivery.
        self.env_marker.write_text("")
        r = self.launch(HNGH_SESSION_EXECUTOR="opencode", **env_extra)
        self.assertEqual(r.returncode, 0, r.stderr)
        marker = self.oc_marker.read_text()
        self.assertIn(marker_keylen, marker)  # key delivered via env
        envargv = self.env_marker.read_text()
        self.assertNotIn(key_value, envargv)  # no VALUE on any argv
        self.assertNotIn(key_name + "=" + key_value, envargv)
        self.assertNotIn(key_value, marker)  # never in child argv either

    def test_opencode_key_value_never_rides_argv(self):
        # opencode-go leg: OPENCODE_API_KEY from a 600 key file
        kfile = self.td / "opencode-key"
        kfile.write_text("k" * 42)
        kfile.chmod(0o600)
        self._assert_key_never_on_argv(
            {"OPENCODE_API_KEY": None, "OPENCODE_KEY_FILE": str(kfile)},
            "OPENCODE_API_KEY", "k" * 42, "keylen=42")

    def test_kimi_key_value_never_rides_argv(self):
        # kimi leg: KIMI_API_KEY from KIMI_AI_KEY (the other quota's key
        # must not ride either)
        (self.auto / "cadence-params.tsv").write_text(
            "# Inventory\n"
            "session-executor\t\ttest\topencode via env override\n"
            "kimi-model\tk3-256k\ttest\ttest row\n")
        self._assert_key_never_on_argv(
            {"OCGO_PROVIDER": "kimi", "KIMI_AI_KEY": "k" * 40,
             "OPENCODE_API_KEY": None},
            "KIMI_API_KEY", "k" * 40, "kimilen=40")

    def test_zai_key_value_never_rides_argv(self):
        # zai leg: ZAI_API_KEY from Z_AI_API_KEY
        (self.auto / "cadence-params.tsv").write_text(
            "# Inventory\n"
            "session-executor\t\ttest\topencode via env override\n"
            "zai-model\tglm-5.3-flash\ttest\ttest row\n")
        self._assert_key_never_on_argv(
            {"OCGO_PROVIDER": "zai", "Z_AI_API_KEY": "z" * 40,
             "OPENCODE_API_KEY": None},
            "ZAI_API_KEY", "z" * 40, "zailen=40")

    def test_failed_session_appends_lesson(self):
        # a real failure (rc!=0, keyword-classified) lands its lesson line
        r = self.launch(HNGH_SESSION_EXECUTOR="opencode", OC_FAIL="1")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("rc=1", r.stdout)
        lessons = (self.auto / "state" / "ocgo-agent-lessons.md").read_text()
        self.assertIn("| bad-execution |", lessons)
        self.assertIn("the step was too big", lessons)

    def test_second_launch_in_same_beat_store_is_not_refused(self):
        # 2026-09-11 beat stall: dream pass and executor (and extra plan
        # slots) shared the beat's single bridge store; the bridge
        # records run-1 per store, so the second --run-start refused
        # record-conflict (rc=75, no session, no spend) and the
        # failfirst machine counted the launch-plane crash. Each launch
        # gets its own store subdir; both launches succeed. The stub
        # bridge emulates the real store contract: one run per store,
        # conflict on re-creation.
        self.bridge.write_text(
            '#!/usr/bin/env bash\n'
            'rec="$OMP_BRIDGE_STORE/record.lisp"\n'
            'if [ -f "$rec" ]; then\n'
            '  echo "conflict labels=record-conflict" >&2; exit 1\n'
            'fi\n'
            'printf "(:IDENTIFIER \\"run-1\\")\\n" > "$rec"\n'
            'echo "run run-1 started $*"\n'
            'exit 0\n')
        self.bridge.chmod(0o755)
        r1 = self.launch(HNGH_SESSION_EXECUTOR="opencode")
        self.assertEqual(r1.returncode, 0, r1.stderr)
        self.assertNotIn("rc=75", r1.stdout)
        r2 = self.launch(HNGH_SESSION_EXECUTOR="opencode")
        self.assertEqual(r2.returncode, 0, r2.stderr)
        self.assertNotIn("rc=75", r2.stdout)

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

    def test_bili_present_wraps_opencode_with_proxy_env(self):
        # bili present and healthy on BILI_OCGO_PORT -> the child runs
        # under the env-only MITM redirect (HTTPS_PROXY + NODE_EXTRA_CA_
        # CERTS); the OPENCODE_CONFIG pin is byte-identical afterwards
        # (zero clobber: the config layer is never written).
        import socket
        bili = self.td / "stubs" / "bili"
        bili.write_text(BILI_STUB)
        bili.chmod(0o755)
        port = 18923
        xdg = self.td / "xdg"
        ca_dir = xdg / "billion-context" / "ca"
        ca_dir.mkdir(parents=True)
        ca = ca_dir / "root-ca.pem"
        ca.write_text("-----BEGIN CERTIFICATE-----\ntest\n")
        cfg = self.auto / "config" / "opencode" / "opencode.jsonc"
        before = cfg.read_bytes()
        r = self.launch(HNGH_SESSION_EXECUTOR="opencode",
                        BILI_OCGO_BIN=str(bili), BILI_OCGO_PORT=str(port),
                        BILI_STUB_PORT=str(port), XDG_DATA_HOME=str(xdg))
        self.assertEqual(r.returncode, 0, r.stderr)
        marker = self.oc_marker.read_text()
        self.assertIn("proxy=http://127.0.0.1:%d" % port, marker)
        self.assertIn("ca=" + str(ca), marker)
        self.assertIn("config=" + str(cfg), marker)
        self.assertEqual(cfg.read_bytes(), before)  # never rewritten
        # the spawned proxy was killed after the run (port released)
        import socket as s
        c = s.socket()
        c.settimeout(2)
        self.assertRaises((ConnectionRefusedError, OSError),
                          c.connect, ("127.0.0.1", port))
        c.close()

    def test_bili_wrapped_exit_code_passthrough(self):
        # rc semantics unchanged under the wrap: timeout wraps opencode
        # directly, bili is a sidecar proxy — the child's rc rides to
        # LAUNCH_RC even when the proxy envs are set
        bili = self.td / "stubs" / "bili"
        bili.write_text(BILI_STUB)
        bili.chmod(0o755)
        port = 18931
        r = self.launch(HNGH_SESSION_EXECUTOR="opencode", OC_FAIL="1",
                        BILI_OCGO_BIN=str(bili), BILI_OCGO_PORT=str(port),
                        BILI_STUB_PORT=str(port))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("rc=1", r.stdout)

    def test_bili_absent_fails_open_uncompressed(self):
        # bili absent -> direct launch with a breadcrumb, no proxy envs,
        # never a failed launch (mirror of the omp bctx-absent pattern);
        # PATH is scoped without npm-global so command -v bili finds
        # nothing, and an ambient bili-wrapped parent's stale proxy envs
        # are stripped from the child
        r = self.launch(HNGH_SESSION_EXECUTOR="opencode",
                        PATH=str(self.td / "stubs") + ":/usr/bin:/bin:/usr/sbin:/sbin")
        self.assertEqual(r.returncode, 0, r.stderr)
        marker = self.oc_marker.read_text()
        self.assertIn("proxy=\n", marker)
        self.assertNotIn("proxy=http", marker)


DELEGATE_DRIVER = """#!/usr/bin/env bash
set -u
. "$AUTO_ROOT/lib/common.sh"
bash "$AUTO_ROOT/lib/ocgo-delegate.sh" "${DELEGATE_SLUG:-dslug}" \\
  "objective body" "${DELEGATE_MIN:-10}"
"""


class OcgoDelegateTool(OcgoLaunch):
    """The omp hngh_opencode tool's launch path (automation/lib/
    ocgo-delegate.sh): the 5h pacer (ocgo+ocgo-agent vs
    opencode-cap-5h-calls) fires BEFORE anything spends (fail-closed
    refusal rc=75, no session, no bridge run), the lessons tail rides in
    the prompt, the timeout clamps to the opencode-agent leg budget
    (1800s), and one bounded session goes through launch_session's
    opencode branch (pack + config pin + bili MITM + R2 emitter
    unchanged — the wrapper reuses, never re-implements)."""

    def setUp(self):
        super().setUp()
        shutil.copy(AUTO / "lib" / "model.sh", self.auto / "lib" / "model.sh")
        shutil.copy(AUTO / "lib" / "ocgo-delegate.sh",
                    self.auto / "lib" / "ocgo-delegate.sh")
        (self.auto / "dashboard").mkdir(exist_ok=True)
        self.driver.write_text(DELEGATE_DRIVER)

    def seed_events(self, source, n):
        # two dbs: the pacer (lib/model.sh quota_pace_blocked_5h) reads
        # $AUTOMATION_ROOT/dashboard/telemetry.db, the R2 emitter reads
        # HNGH_TELEMETRY_DB — in production both are the same file
        db_path = self.auto / "dashboard" / "telemetry.db"
        db = sqlite3.connect(self.telem)
        db.execute(
            "CREATE TABLE IF NOT EXISTS events(ts TEXT, source TEXT,"
            " kind TEXT, identity TEXT, lane TEXT, unit TEXT, model TEXT,"
            " tokens_in INTEGER, tokens_out INTEGER, cost_usd REAL,"
            " wall_s REAL, subject TEXT, refs TEXT, body TEXT)")
        for _ in range(n):
            db.execute("INSERT INTO events(ts, source, kind)"
                       " VALUES (strftime('%Y-%m-%dT%H:%M:%SZ','now'),"
                       " ?, 'model')", (source,))
        db.commit()
        db.close()
        db = sqlite3.connect(db_path)
        db.execute(
            "CREATE TABLE IF NOT EXISTS events(ts TEXT, source TEXT,"
            " kind TEXT, identity TEXT, lane TEXT, unit TEXT, model TEXT,"
            " tokens_in INTEGER, tokens_out INTEGER, cost_usd REAL,"
            " wall_s REAL, subject TEXT, refs TEXT, body TEXT)")
        for _ in range(n):
            db.execute("INSERT INTO events(ts, source, kind)"
                       " VALUES (strftime('%Y-%m-%dT%H:%M:%SZ','now'),"
                       " ?, 'model')", (source,))
        db.commit()
        db.close()

    def test_pacer_blocks_before_any_launch(self):
        # hard cap reached (ocgo source): refusal rc=75, budget message,
        # no session (no oc stub call), no bridge run (store untouched)
        self.seed_events("ocgo", 3)
        r = self.launch(OCGO_CAP_5H_CALLS="3")
        self.assertEqual(r.returncode, 75, r.stdout + r.stderr)
        self.assertIn("used 3 of cap 3", r.stderr)
        self.assertIn("budget", r.stderr)
        self.assertFalse(self.oc_marker.exists())
        self.assertEqual(list((self.td / "store").iterdir()), [])

    def test_pacer_counts_agent_spend_too(self):
        # ocgo-agent events attribute onto the same bucket (R2) — the
        # delegation pacer sees them exactly like model.sh's ocgo_chat
        self.seed_events("ocgo-agent", 3)
        r = self.launch(OCGO_CAP_5H_CALLS="3")
        self.assertEqual(r.returncode, 75, r.stdout + r.stderr)
        self.assertFalse(self.oc_marker.exists())

    def test_pacer_go_launches_one_session_with_telemetry(self):
        # below cap: one bounded session through launch_session's
        # opencode branch; the R2 emitter lands the ocgo-agent row
        self.seed_events("ocgo", 1)
        r = self.launch(OCGO_CAP_5H_CALLS="3")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        marker = self.oc_marker.read_text()
        self.assertIn("--auto", marker)
        self.assertIn("-m opencode-go/glm-5.3-flash", marker)
        self.assertIn("config=" + str(self.auto / "config" / "opencode"
                                      / "opencode.jsonc"), marker)
        self.assertIn("rc=0", r.stdout)
        self.assertIn("disposition=cancelled", r.stdout)
        # the emitted row: one seeded ocgo + one attributed ocgo-agent
        conn = sqlite3.connect(self.telem)
        rows = conn.execute("select source, kind from events").fetchall()
        conn.close()
        self.assertIn(("ocgo", "model"), rows)
        self.assertIn(("ocgo-agent", "model"), rows)

    def test_lessons_tail_rides_in_the_prompt(self):
        # the read side of the lessons loop: previous sessions' lessons
        # reach the executor prompt (append side stays in launch_session)
        lessons = self.auto / "state" / "ocgo-agent-lessons.md"
        lessons.parent.mkdir(exist_ok=True)
        lessons.write_text("# ocgo-agent lessons\n"
                           "2026-09-12 | bad-execution | the step was too big\n")
        r = self.launch()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("the step was too big", self.oc_marker.read_text())

    def test_max_minutes_clamps_to_leg_budget(self):
        # the opencode-agent leg budget (leg-budgets.tsv) caps wall-clock
        # at 1800s: a larger ask is clamped, never passed through
        r = self.launch(DELEGATE_MIN="999")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("timeout_s=1800", r.stdout)

    def test_default_timeout_is_600s(self):
        r = self.launch(DELEGATE_MIN="")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("timeout_s=600", r.stdout)

    def test_kimi_pacer_blocks_before_any_launch(self):
        # kimi provider paces against kimi-daily-cap (the SAME quota the
        # deck-chat leg spends): hard cap reached -> rc=75 refusal, no
        # session, no bridge run
        self.seed_events("kimi", 3)
        r = self.launch(OCGO_PROVIDER="kimi", KIMI_DAILY_CAP_CALLS="3",
                        KIMI_AI_KEY="k" * 40, OPENCODE_API_KEY=None)
        self.assertEqual(r.returncode, 75, r.stdout + r.stderr)
        self.assertIn("kimi used 3 of cap 3", r.stderr)
        self.assertFalse(self.oc_marker.exists())

    def test_kimi_provider_wrapper_reports_provider(self):
        # below cap: one bounded session on the kimi leg; the result
        # line names the provider that actually spent
        (self.auto / "cadence-params.tsv").write_text(
            "# Inventory\n"
            "session-executor\t\ttest\topencode via env override\n"
            "kimi-model\tk3-256k\ttest\ttest row\n")
        r = self.launch(OCGO_PROVIDER="kimi", KIMI_AI_KEY="k" * 40,
                        OPENCODE_API_KEY=None)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        self.assertIn("provider=kimi", r.stdout)
        self.assertIn("-m kimi/k3-256k", self.oc_marker.read_text())


# the subclass reuses the sandbox but runs the wrapper driver — the base
# class's launch-branch tests (which drive launch_session directly and
# assert its stdout shape) must not re-run through it
for _n in [n for n in dir(OcgoLaunch) if n.startswith("test_")]:
    setattr(OcgoDelegateTool, _n, None) # mask inherited: not callable -> skipped
del _n


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
        # Go quota model pinned for the agent; small_model pinned too so
        # lightweight tasks never route to another id (2026-09-11 cost
        # reducer: small_model rides the free local leg, titles/summary only)
        pin = "opencode-go/glm-5.3-flash"
        self.assertEqual(cfg["model"], pin)
        self.assertTrue(cfg["small_model"].startswith("unsloth-local/"),
                        cfg["small_model"])
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
            f". {AUTO}/lib/causes.sh\n"
            f". {AUTO}/lib/launch-session.sh\n"
            # set AFTER sourcing: context-pack.sh (pulled in by
            # launch-session.sh) sources common.sh, which resets
            # AUTOMATION_ROOT to the real repo — setting it before the
            # libs leaked 205 test appends into the real state file
            # (found 2026-09-11)
            f"AUTOMATION_ROOT={tmp}\n"
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
