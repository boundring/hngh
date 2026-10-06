#!/usr/bin/env python3
"""Wizard gate: the installer-wizard routes on the dashboard server.

GET /wizard-state.json assembles the wizard feed (iso candidates, seed
state, step liveness, stage-log tails, verdict, entry block, disk
candidates) from a staged fake workdir; the POST routes drive
jobs/omarchy-unattended-install.sh WITHOUT touching the real machine:
seed runs the driver synchronously (argv asserted against a logging
stub), the privileged steps spawn a stub terminal window exactly once
(full argv asserted), and every guard fails closed -- bad iso paths,
non-https or off-allowlist download urls, missing seed fields, a
second privileged step while one runs, no terminal, no display, and
any wizard POST without the token. Credentials never cross HTTP: a
fake hash in the request body lands nowhere in argv, state, or reply.

Run: python3 automation/tests/test-dashboard-wizard.py
"""
import importlib.util
import json
import os
import re
import shlex
import stat
import tempfile
import threading
import time
import unittest
import urllib.error
import urllib.request
from pathlib import Path

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # automation/
DS_PATH = os.path.join(ROOT, "dashboard-server.py")

STUB_DRIVER = '''#!/usr/bin/env bash
# stand-in for jobs/omarchy-unattended-install.sh: logs argv
printf '%s\n' "$@" >> "$HNGH_STUB_DRIVER_LOG"
echo "driver: seed staged"
echo "driver: cidata baked"
exit "${HNGH_STUB_DRIVER_RC:-0}"
'''

STUB_BB = '''#!/usr/bin/env bash
# stand-in for jobs/omarchy-boot-build.sh: canned emit-entry block
printf '%s\n' "$*" >> "$HNGH_STUB_BB_LOG"
echo "ENTRY BLOCK LINE"
echo "omarchy-boot-build: emit-entry: cannot resolve esp (fail-closed, no entry block)" >&2
exit "${HNGH_STUB_BB_RC:-0}"
'''
STUB_TERM = '''#!/usr/bin/env bash
# stand-in for the terminal binary: logs the exact argv it was exec'd with
printf '%s\n' "$@" > "$HNGH_STUB_TERM_LOG"
exit 0
'''

STUB_CURL = '''#!/usr/bin/env bash
# stand-in for curl: logs the exact argv it was given
printf '%s\n' "$@" > "$HNGH_STUB_CURL_LOG"
exit 0
'''


def _load():
    spec = importlib.util.spec_from_file_location("ds_wizard", DS_PATH)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


ds = _load()


class _Result:
    def __init__(self, rc, out="", err=""):
        self.returncode = rc
        self.stdout = out
        self.stderr = err


LSBLK_JSON = json.dumps({
    "blockdevices": [
        {"name": "sda", "size": "500G", "fstype": None,
         "partuuid": "P-ROOT", "mountpoints": ["/"], "children": [
             {"name": "sda1", "size": "500G", "fstype": "ext4",
              "partuuid": "P-EFI", "mountpoints": ["/boot"]}]},
        {"name": "testdisk", "size": "40G", "fstype": None,
         "partuuid": "P-DISK", "mountpoints": [None], "children": []},
    ]})


class Wizard(unittest.TestCase):
    maxDiff = None

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._teardown)
        base = self.base = Path(self.tmp.name)
        stub = self.stub = base / "stubbin"
        stub.mkdir()
        self.stubs = {}
        for name, body in (("stub-driver", STUB_DRIVER), ("stub-bb", STUB_BB),
                           ("stub-term-a", STUB_TERM), ("stub-term-b", STUB_TERM),
                           ("curl", STUB_CURL)):
            path = stub / name
            path.write_text(body)
            path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
            self.stubs[name] = str(path)
        dash = base / "dashboard"
        dash.mkdir()
        (dash / "index.html").write_text("<html><head></head><body>idx</body></html>")
        (dash / "wizard.html").write_text("<html><head></head><body>wiz</body></html>")
        (dash / "desk.html").write_text("<html><head></head><body>desk</body></html>")
        self.secrets = base / "secrets"
        self.secrets.mkdir()
        self.logdir = base / "logs"
        self.logdir.mkdir()
        self.downloads = base / "downloads"
        self.downloads.mkdir()
        self.stub_log = base / "stub.log"
        self.term_log = base / "term.log"
        self.curl_log = base / "curl.log"
        self.bb_log = base / "bb.log"
        self.driver_log = base / "driver.log"
        self._saved_env = {}
        for key in ("PATH", "DISPLAY", "WAYLAND_DISPLAY", "HNGH_TERMINAL",
                    "TERMINAL", "HNGH_STUB_DRIVER_LOG", "HNGH_STUB_BB_LOG",
                    "HNGH_STUB_TERM_LOG", "HNGH_STUB_CURL_LOG"):
            self._saved_env[key] = os.environ.get(key)
        os.environ["PATH"] = str(stub) + os.pathsep + os.environ.get("PATH", "")
        os.environ["DISPLAY"] = ":0"
        os.environ.pop("WAYLAND_DISPLAY", None)
        os.environ.pop("HNGH_TERMINAL", None)
        os.environ.pop("TERMINAL", None)
        os.environ["HNGH_STUB_DRIVER_LOG"] = str(self.driver_log)
        os.environ["HNGH_STUB_BB_LOG"] = str(self.bb_log)
        os.environ["HNGH_STUB_TERM_LOG"] = str(self.term_log)
        os.environ["HNGH_STUB_CURL_LOG"] = str(self.curl_log)
        ds.DASHBOARD = str(dash)
        ds.TOKEN_FILE = str(base / "token.txt")
        ds.WIZARD_SECRETS_HOME = str(self.secrets)
        ds.WIZARD_LOGDIR = str(self.logdir)
        ds.WIZARD_DOWNLOADS = str(self.downloads)
        ds.WIZARD_ISO_DIRS = ""
        ds.WIZARD_DRIVER = self.stubs["stub-driver"]
        ds.WIZARD_BOOT_BUILD = self.stubs["stub-bb"]
        self.qemu = False
        self.lsblk_json = LSBLK_JSON
        ds._run_ro = self._fake_run
        self.token = ds.load_token()
        self.httpd = ds.ThreadingHTTPServer(("127.0.0.1", 0), ds.Handler)
        threading.Thread(target=self.httpd.serve_forever, daemon=True).start()
        self.port = self.httpd.server_address[1]

    def _teardown(self):
        self.httpd.shutdown()
        self.httpd.server_close()
        for key, val in self._saved_env.items():
            if val is None:
                os.environ.pop(key, None)
            else:
                os.environ[key] = val
        self.tmp.cleanup()

    def _fake_run(self, argv, timeout=15):
        if argv[0] == "lsblk":
            return _Result(0, self.lsblk_json, "")
        if argv[:2] == ["pgrep", "-af"]:
            out = "1234 qemu-system-x86_64\n" if self.qemu else ""
            return _Result(0 if self.qemu else 1, out, "")
        return _Result(1, "", "unexpected probe %r" % (argv,))

    def post(self, route, obj, token=True):
        req = urllib.request.Request(
            "http://127.0.0.1:%d/%s" % (self.port, route),
            data=json.dumps(obj).encode(), method="POST")
        req.add_header("Content-Type", "application/json")
        if token:
            req.add_header("X-Hngh-Token", self.token)
        try:
            resp = urllib.request.urlopen(req, timeout=30)
            return resp.status, json.loads(resp.read().decode())
        except urllib.error.HTTPError as exc:
            return exc.code, json.loads(exc.read().decode())

    def get(self, route):
        try:
            resp = urllib.request.urlopen(
                "http://127.0.0.1:%d/%s" % (self.port, route), timeout=30)
            return resp.status, resp.read().decode()
        except urllib.error.HTTPError as exc:
            return exc.code, exc.read().decode()

    def get_json(self, route):
        status, body = self.get(route)
        return status, json.loads(body)

    def wait_log(self, path, count=1, timeout=10):
        end = time.time() + timeout
        while time.time() < end:
            if os.path.isfile(path):
                lines = Path(path).read_text().splitlines()
                if len(lines) >= count:
                    return lines
            time.sleep(0.05)
        self.fail("stub log %s never reached %d line(s)" % (path, count))

    def wait_pid_gone(self, pid, timeout=10):
        end = time.time() + timeout
        while time.time() < end:
            try:
                os.kill(pid, 0)
            except OSError:
                return
            time.sleep(0.05)
        self.fail("stub pid %s never exited" % pid)

    def write_params(self, **kw):
        params = {"iso": str(self.downloads / "omarchy-4.iso"), "user": "alice",
                  "disk": "/dev/testdisk", "packages": [], "repos": [],
                  "services": [], "authkey_path": "", "defer": True}
        params.update(kw)
        (self.secrets / "wizard-params.json").write_text(json.dumps(params))
        return params

    def script_for(self, argstr):
        repo = os.path.dirname(ds.ROOT)
        return ("cd %s && bash automation/jobs/"
                "omarchy-unattended-install.sh %s;"
                " rc=$?; echo \"=== exit rc=$rc ===\"; read -r"
                % (shlex.quote(repo), argstr))

    def expected_cmd(self, argv):
        return ds.scrub.redact_home(shlex.join(argv))

    # ---- state feed -------------------------------------------------

    def test_state_shape_from_staged_workdir(self):
        iso = self.downloads / "omarchy-4.iso"
        iso.write_text("x" * 10)
        work = self.secrets / "20261006T010203Z"
        work.mkdir()
        (work / "cidata.iso").write_text("c")
        (work / "run-manifest").write_text("mode=pilot\n")
        (self.logdir / "seed-20261006T010203Z.log").write_text("seed one\nseed two\n")
        (self.logdir / "run-20261006T010204Z.log").write_text("run one\n")
        (self.logdir / "verify-20261006T010205Z.log").write_text("booted\nverdict: BOOTED+SSH\n")
        (self.logdir / "full-20261006T010206Z.log").write_text("full one\n")
        (self.secrets / "entry-block.txt").write_text("ENTRY BLOCK\n")
        key1 = self.secrets / "tailscale-authkey.txt"
        key1.write_text("KEYFILEMARKER\n")
        key2 = work / "authkey-file.key"
        key2.write_text("KEYFILEMARKER\n")
        params = self.write_params(iso=str(iso), packages=["git"])
        expect_params = {k: v for k, v in params.items() if k != "iso"}
        status, body = self.get_json("wizard-state.json")
        self.assertEqual(200, status)
        self.assertEqual({"generated", "iso", "isos", "authkey_files",
                          "seed", "steps", "qemu_running", "logs", "verdict",
                          "entry", "disks"}, set(body))
        self.assertRegex(body["generated"], r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")
        self.assertEqual(str(iso), body["iso"])
        self.assertEqual({"path", "name", "size", "mtime"}, set(body["isos"][0]))
        self.assertEqual("omarchy-4.iso", body["isos"][0]["name"])
        self.assertEqual(10, body["isos"][0]["size"])
        self.assertEqual(sorted([str(key1), str(key2)]),
                         sorted(body["authkey_files"]))
        self.assertNotIn("KEYFILEMARKER", json.dumps(body))
        seed = body["seed"]
        self.assertTrue(seed["workdir"].endswith("20261006T010203Z"))
        self.assertTrue(seed["cidata"])
        self.assertTrue(seed["manifest"])
        self.assertEqual(expect_params, seed["params"])
        self.assertEqual({"pilot", "go-real", "verify", "download"}, set(body["steps"]))
        for step in body["steps"].values():
            self.assertEqual({"pid", "running"}, set(step))
        self.assertFalse(body["qemu_running"])
        self.assertEqual({"seed", "pilot", "go-real", "verify", "download"},
                         set(body["logs"]))
        self.assertEqual("seed-20261006T010203Z.log", body["logs"]["seed"]["file"])
        self.assertEqual("seed one\nseed two", body["logs"]["seed"]["tail"])
        self.assertEqual("run-20261006T010204Z.log", body["logs"]["pilot"]["file"])
        self.assertEqual("verify-20261006T010205Z.log", body["logs"]["verify"]["file"])
        self.assertEqual("BOOTED+SSH", body["verdict"])
        self.assertEqual("ENTRY BLOCK\n", body["entry"])
        self.assertEqual([("sda", False), ("sda1", False),
                           ("testdisk", True)],
                         [(d["name"], d["unmounted"])
                          for d in body["disks"]])
        self.assertEqual({"name", "size", "fstype", "partuuid", "mountpoints",
                          "unmounted"}, set(body["disks"][0]))

    def test_state_409_when_drivers_missing(self):
        ds.WIZARD_DRIVER = str(self.base / "missing-driver.sh")
        status, body = self.get_json("wizard-state.json")
        self.assertEqual(409, status)
        self.assertFalse(body["ok"])
        self.assertIn("omarchy-unattended-install.sh", body["remediation"])

    def test_state_verdict_falls_back_to_full_log(self):
        (self.logdir / "full-20261006T010206Z.log").write_text("verdict: TIMEOUT\n")
        status, body = self.get_json("wizard-state.json")
        self.assertEqual(200, status)
        self.assertEqual("TIMEOUT", body["verdict"])

    # ---- iso select -------------------------------------------------

    def test_iso_select_validates_path_and_name(self):
        good = self.downloads / "omarchy-4.iso"
        good.write_text("x")
        status, body = self.post("wizard/iso-select", {"path": str(good)})
        self.assertEqual(201, status)
        self.assertEqual(str(good), body["path"])
        bad_name = self.downloads / "linux.iso"
        bad_name.write_text("x")
        status, body = self.post("wizard/iso-select", {"path": str(bad_name)})
        self.assertEqual(400, status)
        self.assertIn("omarchy", body["error"])
        status, body = self.post(
            "wizard/iso-select", {"path": str(self.downloads / "absent.iso")})
        self.assertEqual(400, status)
        status, body = self.post("wizard/iso-select", {})
        self.assertEqual(400, status)

    def test_iso_select_persists_selection(self):
        good = self.downloads / "omarchy-5.iso"
        good.write_text("x")
        self.post("wizard/iso-select", {"path": str(good)})
        status, body = self.get_json("wizard-state.json")
        self.assertEqual(str(good), body["iso"])
        saved = json.loads(
            (self.secrets / "wizard-params.json").read_text())
        self.assertEqual(str(good), saved["iso"])

    # ---- iso download ----------------------------------------------

    def test_iso_download_refuses_http_and_offlist(self):
        status, body = self.post("wizard/iso-download",
                                 {"url": "http://omarchy.org/omarchy.iso"})
        self.assertEqual(400, status)
        self.assertIn("https", body["error"])
        status, body = self.post("wizard/iso-download",
                                 {"url": "https://evil.example/omarchy.iso"})
        self.assertEqual(400, status)
        self.assertIn("allowlist", body["error"])
        status, body = self.post(
            "wizard/iso-download", {"url": "https://omarchy.org.evil.example/x.iso"})
        self.assertEqual(400, status)
        status, body = self.post("wizard/iso-download", {})
        self.assertEqual(400, status)

    def test_iso_download_spawns_curl_argv(self):
        url = "https://omarchy.org/download/omarchy-4.iso"
        status, body = self.post("wizard/iso-download", {"url": url})
        self.assertEqual(201, status)
        self.assertTrue(body["ok"])
        self.assertTrue(body["pid"])
        self.assertEqual(str(self.downloads / "omarchy-4.iso"), body["path"])
        lines = self.wait_log(self.curl_log, 6)
        self.assertEqual(["-L", "--proto-redir", "=https", "-o",
                          str(self.downloads / "omarchy-4.iso"), url], lines)

    def test_iso_download_one_at_a_time(self):
        (self.secrets / "wizard-download.pid").write_text(str(os.getpid()))
        status, body = self.post("wizard/iso-download",
                                 {"url": "https://github.com/a/omarchy.iso"})
        self.assertEqual(409, status)
        self.assertFalse(body["ok"])
        self.assertIn("download", body["error"])
        self.assertIn("remediation", body)

    # ---- seed ------------------------------------------------------

    def test_seed_builds_driver_command(self):
        iso = self.downloads / "omarchy-4.iso"
        iso.write_text("x")
        self.post("wizard/iso-select", {"path": str(iso)})
        status, body = self.post("wizard/seed", {
            "user": "alice", "disk": "/dev/testdisk",
            "packages": ["git", "ripgrep"], "repos": ["https://example.com/r.git"],
            "services": ["ssh"], "authkey_path": "", "defer": True})
        self.assertEqual(201, status)
        self.assertEqual(0, body["rc"])
        self.assertIn("driver: seed staged", body["tail"])
        lines = self.wait_log(self.driver_log, 17)
        self.assertEqual(["seed", "--yes", "--disk", "/dev/testdisk",
                          "--user", "alice", "--iso", str(iso),
                          "--package", "git", "--package", "ripgrep",
                          "--repo", "https://example.com/r.git",
                          "--service", "ssh", "--defer-provisioning"], lines)

    def test_seed_refuses_missing_or_bad_fields(self):
        for body in ({"disk": "/dev/testdisk", "defer": True},
                     {"user": "alice", "defer": True},
                     {"user": "Bad Name", "disk": "/dev/testdisk", "defer": True},
                     {"user": "alice", "disk": "/dev/testdisk;rm", "defer": True}):
            status, resp = self.post("wizard/seed", body)
            self.assertEqual(400, status, body)
            self.assertFalse(resp["ok"])
        status, resp = self.post("wizard/seed", {
            "user": "alice", "disk": "/dev/testdisk",
            "packages": ["git;rm -rf"], "defer": True})
        self.assertEqual(400, status)
        status, resp = self.post("wizard/seed", {
            "user": "alice", "disk": "/dev/testdisk",
            "authkey_path": str(self.base / "absent.key"), "defer": True})
        self.assertEqual(400, status)
        self.assertFalse(os.path.isfile(self.driver_log))

    def test_seed_non_defer_refused_with_remediation(self):
        status, body = self.post("wizard/seed",
                                 {"user": "alice", "disk": "/dev/testdisk"})
        self.assertEqual(400, status)
        self.assertIn("defer", body["error"])
        self.assertIn("--credentials-hash", body["remediation"])

    def test_seed_never_carries_credentials(self):
        keyfile = self.base / "auth.key"
        keyfile.write_text("KEYFILEMARKER-supersecret\n")
        status, body = self.post("wizard/seed", {
            "user": "alice", "disk": "/dev/testdisk",
            "authkey_path": str(keyfile), "defer": True,
            "credentials_hash": "$6$saltsalt$SUPERSECRETMARKER"})
        self.assertEqual(201, status)
        lines = self.wait_log(self.driver_log, 9)
        argv_text = "\n".join(lines)
        self.assertNotIn("SUPERSECRETMARKER", argv_text)
        self.assertNotIn("KEYFILEMARKER", argv_text)
        self.assertIn("--tailscale-authkey", lines)
        self.assertEqual(str(keyfile), lines[lines.index("--tailscale-authkey") + 1])
        self.assertNotIn("--credentials-hash", lines)
        _, state = self.get_json("wizard-state.json")
        state_text = json.dumps(state)
        self.assertNotIn("SUPERSECRETMARKER", state_text)
        self.assertNotIn("KEYFILEMARKER", state_text)
        self.assertNotIn("SUPERSECRETMARKER", json.dumps(body))
        self.assertNotIn("KEYFILEMARKER", json.dumps(body))

    def test_seed_driver_failure_returns_502(self):
        os.environ["HNGH_STUB_DRIVER_RC"] = "3"
        self.addCleanup(os.environ.pop, "HNGH_STUB_DRIVER_RC", None)
        status, body = self.post("wizard/seed",
                                 {"user": "alice", "disk": "/dev/testdisk",
                                  "defer": True})
        self.wait_log(self.driver_log, 7)
        self.assertEqual(502, status)
        self.assertEqual(3, body["rc"])
        self.assertIn("driver: seed staged", body["tail"])

    # ---- privileged terminal window --------------------------------

    def expect_409(self, status, body, needle):
        self.assertEqual(409, status)
        self.assertFalse(body["ok"])
        self.assertIn(needle, body["error"])
        self.assertIn("remediation", body)

    def test_terminal_resolution_prefers_hngh_terminal(self):
        self.write_params()
        os.environ["HNGH_TERMINAL"] = self.stubs["stub-term-a"]
        os.environ["TERMINAL"] = self.stubs["stub-term-b"]
        iso = str(self.downloads / "omarchy-4.iso")
        status, body = self.post("wizard/terminal", {"step": "pilot"})
        self.assertEqual(201, status)
        argv = [self.stubs["stub-term-a"], "-e", "bash", "-c",
                self.script_for("run --yes --pilot --disk /dev/testdisk"
                                " --iso %s" % iso)]
        self.assertEqual(self.expected_cmd(argv), body["cmd"])

    def test_terminal_falls_back_env_then_which(self):
        self.write_params()
        os.environ["TERMINAL"] = self.stubs["stub-term-b"]
        status, body = self.post("wizard/terminal", {"step": "verify"})
        self.assertEqual(201, status)
        self.assertTrue(body["cmd"].startswith(
            ds.scrub.redact_home(self.stubs["stub-term-b"])))
        self.wait_pid_gone(body["pid"])
        os.environ.pop("TERMINAL")
        term2 = self.base / "term2"
        term2.mkdir()
        kitty = term2 / "kitty"
        kitty.write_text(STUB_TERM)
        kitty.chmod(kitty.stat().st_mode | stat.S_IXUSR)
        os.environ["PATH"] = str(term2) + os.pathsep + os.environ["PATH"]
        status, body = self.post("wizard/terminal", {"step": "verify"})
        self.assertEqual(201, status)
        self.assertTrue(body["cmd"].startswith(ds.scrub.redact_home(str(kitty))))

    def test_terminal_409_without_display(self):
        self.write_params()
        os.environ["HNGH_TERMINAL"] = self.stubs["stub-term-a"]
        os.environ.pop("DISPLAY", None)
        self.expect_409(*self.post("wizard/terminal", {"step": "pilot"}),
                        "display")

    def test_terminal_409_without_terminal(self):
        self.write_params()
        os.environ["PATH"] = str(self.stub)
        self.expect_409(*self.post("wizard/terminal", {"step": "pilot"}),
                        "terminal")

    def test_terminal_bad_step_and_missing_params(self):
        self.write_params()
        status, body = self.post("wizard/terminal", {"step": "nuke"})
        self.assertEqual(400, status)
        (self.secrets / "wizard-params.json").unlink()
        self.expect_409(*self.post("wizard/terminal", {"step": "pilot"}),
                        "seed params missing")

    def test_terminal_one_at_a_time(self):
        self.write_params()
        (self.secrets / "wizard-pilot.pid").write_text(str(os.getpid()))
        self.expect_409(*self.post("wizard/terminal", {"step": "verify"}),
                        "already running")

    def test_terminal_qemu_running_409(self):
        self.write_params()
        self.qemu = True
        self.expect_409(*self.post("wizard/terminal", {"step": "pilot"}),
                        "qemu")

    def test_terminal_spawn_argv_exact(self):
        params = self.write_params()
        cases = [
            ("pilot", "run --yes --pilot --disk /dev/testdisk --iso %s"
                      % params["iso"]),
            ("go-real", "full --yes --go-real --disk /dev/testdisk --iso %s"
                        " --user alice" % params["iso"]),
            ("verify", "verify --yes --disk /dev/testdisk"),
        ]
        for step, argstr in cases:
            term_log = self.base / ("term-%s.log" % step)
            os.environ["HNGH_STUB_TERM_LOG"] = str(term_log)
            os.environ["HNGH_TERMINAL"] = self.stubs["stub-term-a"]
            status, body = self.post("wizard/terminal", {"step": step})
            self.assertEqual(201, status, (step, body))
            argv = [self.stubs["stub-term-a"], "-e", "bash", "-c",
                    self.script_for(argstr)]
            lines = self.wait_log(term_log, 4)
            self.assertEqual(argv[1:], lines, step)
            self.assertEqual(self.expected_cmd(argv), body["cmd"], step)
            pidfile = self.secrets / ("wizard-%s.pid" % step)
            self.assertEqual(str(body["pid"]), pidfile.read_text().strip())

    # ---- entry preview ---------------------------------------------

    def test_entry_preview_writes_block(self):
        status, body = self.post("wizard/entry-preview", {})
        self.assertEqual(201, status)
        self.assertEqual("ENTRY BLOCK LINE\n", body["entry"])
        self.assertEqual("ENTRY BLOCK LINE\n",
                         (self.secrets / "entry-block.txt").read_text())
        _, state = self.get_json("wizard-state.json")
        self.assertEqual("ENTRY BLOCK LINE\n", state["entry"])

    def test_entry_preview_fail_closed_502(self):
        os.environ["HNGH_STUB_BB_RC"] = "2"
        self.addCleanup(os.environ.pop, "HNGH_STUB_BB_RC", None)
        status, body = self.post("wizard/entry-preview", {})
        self.assertEqual(502, status)
        self.assertEqual(2, body["rc"])
        self.assertIn("fail-closed", body["tail"])
        self.assertFalse(os.path.isfile(self.secrets / "entry-block.txt"))

    # ---- contract, wiring, frontend --------------------------------

    def test_token_required_on_wizard_posts(self):
        routes = [("wizard/iso-select", {"path": "/x"}),
                  ("wizard/iso-download", {"url": "https://omarchy.org/x.iso"}),
                  ("wizard/seed", {"user": "alice", "disk": "/dev/testdisk"}),
                  ("wizard/terminal", {"step": "pilot"}),
                  ("wizard/entry-preview", {})]
        for route, body in routes:
            status, resp = self.post(route, body, token=False)
            self.assertEqual(403, status, route)
            req = urllib.request.Request(
                "http://127.0.0.1:%d/%s" % (self.port, route),
                data=json.dumps(body).encode(), method="POST")
            req.add_header("Content-Type", "application/json")
            req.add_header("X-Hngh-Token", "0" * 32)
            try:
                urllib.request.urlopen(req, timeout=10)
                self.fail("bad token accepted on %s" % route)
            except urllib.error.HTTPError as exc:
                self.assertEqual(403, exc.code, route)

    def test_dispatch_wiring(self):
        source = open(DS_PATH).read()
        for route, handler in (
                ("wizard/iso-select", "self._wizard_iso_select"),
                ("wizard/iso-download", "self._wizard_iso_download"),
                ("wizard/seed", "self._wizard_seed"),
                ("wizard/terminal", "self._wizard_terminal"),
                ("wizard/entry-preview", "self._wizard_entry_preview")):
            self.assertRegex(source, r'"%s"\s*:\s*%s'
                             % (re.escape(route), re.escape(handler)))
        self.assertIn('"/wizard-state.json"', source)
        self.assertIn('"wizard.html"', source)

    def test_frontend_files_clean_and_ids(self):
        required = ["wizerr", "step-iso", "step-seed", "step-pilot",
                    "step-verify", "step-go-real", "step-entry", "step-done",
                    "iso-url", "btn-iso-download", "opt-user", "opt-disk",
                    "opt-packages", "opt-repos", "opt-services", "opt-authkey",
                    "opt-defer", "btn-seed", "btn-pilot", "btn-verify",
                    "btn-go-real", "go-real-check", "formatted-warning",
                    "log-seed", "log-pilot", "log-verify", "log-go-real",
                    "log-download", "entry-block", "btn-entry", "wiz-line"]
        home = os.path.expanduser("~")
        texts = {}
        for name in ("wizard.html", "wizard-view.js", "wizard.css"):
            path = os.path.join(ROOT, "dashboard", name)
            self.assertTrue(os.path.isfile(path), name)
            raw = open(path, "rb").read()
            raw.decode("ascii")  # ASCII-only: raises on anything else
            text = raw.decode()
            texts[name] = text
            self.assertNotIn(home, text, name)
            self.assertNotIn("setInterval(", text, name)
            self.assertNotIn("http://", text, name)
            self.assertNotIn("https://", text, name)
        for ident in required:
            self.assertIn('id="%s"' % ident, texts["wizard.html"], ident)
            self.assertIn(ident, texts["wizard-view.js"], ident)
        for route in ("wizard-state.json", "wizard/iso-select",
                      "wizard/iso-download", "wizard/seed", "wizard/terminal",
                      "wizard/entry-preview"):
            self.assertIn(route, texts["wizard-view.js"], route)

    def test_desk_links_wizard(self):
        self.assertIn('href="wizard.html"',
                      open(os.path.join(ROOT, "dashboard", "desk.html")).read())


if __name__ == "__main__":
    unittest.main()
