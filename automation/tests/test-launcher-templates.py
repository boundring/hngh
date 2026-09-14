#!/usr/bin/env python3
"""launcher-templates, stall-recovery step 4. Hermetic: extracts the real
_launchers() merge code from dashboard-server.py via sed (no server run),
exercises the ui-config launchers merge contract, and drives
jobs/tmux-observe.sh against a stub tmux binary in a PATH sandbox (no
display, no real sessions touched)."""

import json
import os
import re
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SERVER = ROOT / "dashboard-server.py"
OBS = ROOT / "jobs" / "tmux-observe.sh"


def _sed(pattern):
    src = subprocess.run(["sed", "-n", pattern, str(SERVER)],
                         capture_output=True, text=True, check=True).stdout
    assert src.strip(), "extraction failed: " + pattern
    return src


# real merge path lifted from the server source (constants + _launchers),
# same technique as test-quota-routing.sh does for select_model
SNIPPET = "\n".join([
    _sed("/^SESSION_RE = /p"),
    _sed("/^DEFAULT_LAUNCHERS = {/,/^}/p"),
    _sed("/^def _launchers/,/^    return merged/p"),
])


def _launchers(config_path):
    ns = {"os": os, "json": json, "re": re, "UI_CONFIG": config_path}
    exec(SNIPPET, ns)
    return ns["_launchers"](), ns["SESSION_RE"]


# stub tmux: records every argv line to $TMUX_STUB_LOG, prints an
# incrementing pane id for any -P call, fakes has-session from a flag file
TMUX_STUB = """#!/bin/sh
printf '%s\\n' "$*" >> "$TMUX_STUB_LOG"
[ "$1" = has-session ] && { [ -e "$TMUX_STUB_EXISTS" ]; exit $?; }
for a in "$@"; do
  if [ "$a" = -P ]; then
    n=$(cat "$TMUX_STUB_CNT" 2>/dev/null || echo 0)
    echo $((n + 1)) > "$TMUX_STUB_CNT"
    echo "%$n"
    exit 0
  fi
done
exit 0
"""


class LauncherMerge(unittest.TestCase):
    def merged(self, text):
        with tempfile.TemporaryDirectory() as td:
            path = os.path.join(td, "ui-config.json")
            if text is not None:
                with open(path, "w") as f:
                    f.write(text)
            return _launchers(path)

    def test_tmux_observe_survives_merge_with_defaults(self):
        obs = "bash " + str(OBS)
        m, _ = self.merged(json.dumps({"launchers": {"tmux-observe": obs}}))
        self.assertEqual(m["tmux-observe"], obs)
        self.assertIn("konsole-tail", m)  # built-ins stay alongside

    def test_registered_key_matches_session_re(self):
        _, session_re = self.merged(None)
        self.assertTrue(session_re.fullmatch("tmux-observe"))

    def test_invalid_key_rejected(self):
        m, _ = self.merged(json.dumps({"launchers": {"bad key!": "x"}}))
        self.assertNotIn("bad key!", m)

    def test_non_string_template_rejected(self):
        m, _ = self.merged(json.dumps({"launchers": {"num-launcher": 3}}))
        self.assertNotIn("num-launcher", m)

    def test_missing_config_defaults_only(self):
        m, _ = self.merged(None)
        self.assertEqual(sorted(m), ["konsole-store", "konsole-tail"])

    def test_broken_json_defaults_only(self):
        m, _ = self.merged("{not json")
        self.assertEqual(sorted(m), ["konsole-store", "konsole-tail"])


@unittest.skipUnless(shutil.which("pygmentize"),
                     "pygmentize must resolve for the pane-build path")
class ObserveScript(unittest.TestCase):
    def setUp(self):
        td = tempfile.TemporaryDirectory()
        self.addCleanup(td.cleanup)
        sb = Path(td.name)
        self.stub_log = sb / "tmux-args.log"
        self.stub_log.touch()
        bin_ = sb / "bin"
        bin_.mkdir()
        stub = bin_ / "tmux"
        stub.write_text(TMUX_STUB)
        stub.chmod(0o755)
        for b in ("bash", "sh", "find", "sort", "cut", "head", "date",
                  "dirname", "pygmentize"):
            (bin_ / b).symlink_to(shutil.which(b))
        self.env = dict(os.environ, PATH=str(bin_), AUTOMATION_ROOT=str(sb),
                        TMUX_STUB_LOG=str(self.stub_log),
                        TMUX_STUB_CNT=str(sb / "cnt"),
                        TMUX_STUB_EXISTS=str(sb / "exists-flag"))
        self.logs = sb / "logs"

    def run_obs(self):
        return subprocess.run(["bash", str(OBS)], env=self.env,
                              capture_output=True, text=True)

    def args(self):
        return self.stub_log.read_text().splitlines()

    def test_no_sessions_fail_closed(self):
        r = self.run_obs()
        self.assertEqual(r.returncode, 0)
        self.assertNotIn("new-session", r.stderr + str(self.args()))
        self.assertIn("tmux-observe:", r.stderr)  # breadcrumb, not silence

    def test_stale_logs_ignored(self):
        self.logs.mkdir()
        old = self.logs / "overnight-stale-20260901T000000.log"
        old.write_text("done\n")
        os.utime(old, (1000000000, 1000000000))
        r = self.run_obs()
        self.assertEqual(r.returncode, 0)
        self.assertNotIn("new-session", str(self.args()))

    def test_builds_labeled_panes_per_fresh_log(self):
        self.logs.mkdir()
        a = self.logs / "overnight-plan-alpha-20260913T120000.log"
        b = self.logs / "overnight-plan-beta-20260913T120001.log"
        a.write_text("alpha out\n")
        b.write_text("beta out\n")
        r = self.run_obs()
        self.assertEqual(r.returncode, 0, r.stderr)
        lines = self.args()
        self.assertTrue(any("new-session" in l and "-s hngh-obs" in l
                            for l in lines), lines)
        self.assertTrue(any("split-window" in l for l in lines), lines)
        self.assertTrue(any("-T plan-alpha-20260913T120000" in l
                            for l in lines), lines)
        self.assertTrue(any("-T plan-beta-20260913T120001" in l
                            for l in lines), lines)
        self.assertTrue(any("select-layout" in l and " tiled" in l
                            for l in lines), lines)

    def test_replaces_existing_session(self):
        Path(self.env["TMUX_STUB_EXISTS"]).touch()
        self.logs.mkdir()
        (self.logs / "overnight-plan-only-20260913T120002.log").write_text("x\n")
        r = self.run_obs()
        self.assertEqual(r.returncode, 0, r.stderr)
        lines = self.args()
        self.assertIn("kill-session -t hngh-obs", lines)
        self.assertLess(lines.index("kill-session -t hngh-obs"),
                        next(i for i, l in enumerate(lines)
                             if "new-session" in l))


if __name__ == "__main__":
    unittest.main()
