#!/usr/bin/env python3
"""service-ctl contract, hermetic.

A fake `systemctl` on PATH (via HNGH_SERVICE_SYSTEMCTL seam) plays the
unit manager: `cat` succeeds only for installed units, `start` records
its invocation. The report-queue writer is stubbed the same way. No real
unit is ever touched; refusal paths must exit 2 BEFORE any systemctl call.
"""

import json
import os
import socket
import subprocess
import threading
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CTL = ROOT / "scripts" / "service-ctl.sh"

STUB = """#!/usr/bin/env bash
# fake systemctl: logs every call; cat succeeds for installed units only
echo "$*" >> "$STUB_LOG"
case "$2 $3" in
  cat\\ llama-server.service|cat\\ unsloth-studio.service) exit 0 ;;
  # unsloth-warm is "not installed" in this fixture: cat fails for it
  cat\\ unsloth-warm.service) exit 1 ;;
  cat\\ *) exit 1 ;;
  show\\ *) printf 'active\\n' ;;
  *) exit 0 ;;
esac
"""

RQ_STUB = """#!/usr/bin/env python3
import os, sys
with open(os.environ["RQ_LOG"], "a") as fh:
    fh.write("report-queue " + " ".join(sys.argv[1:]) + "\\n")
"""


class ServiceCtl(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.bin = self.tmp / "bin"
        self.bin.mkdir()
        self.stub_log = self.tmp / "systemctl.log"
        self.rq_log = self.tmp / "report-queue.log"
        self._install("systemctl", STUB)
        scripts = self.tmp / "scripts"
        scripts.mkdir()
        rq = scripts / "report-queue"
        rq.write_text(RQ_STUB)
        rq.chmod(0o755)
        self.env = dict(
            os.environ,
            HNGH_SERVICE_SYSTEMCTL=str(self.bin / "systemctl"),
            HNGH_HOME=str(self.tmp),          # report-queue stub lives here
            HNGH_REPORT_ROOT=str(self.tmp),
            STUB_LOG=str(self.stub_log),
            RQ_LOG=str(self.rq_log),
            STATE_FILE=str(self.tmp / "STATE.md"),
        )

    def _install(self, name, body):
        p = self.bin / name
        p.write_text(body)
        p.chmod(0o755)

    def run_ctl(self, *args, **kw):
        return subprocess.run(
            [str(CTL), *args], env=dict(self.env, **kw.get("extra", {})),
            capture_output=True, text=True, timeout=30)

    def stub_calls(self):
        return self.stub_log.read_text() if self.stub_log.exists() else ""

    def test_non_allowlisted_unit_refused_first(self):
        p = self.run_ctl("other.service", "start")
        self.assertEqual(p.returncode, 2)
        self.assertEqual(self.stub_calls(), "")  # nothing ran at all

    def test_lifecycle_verb_refused(self):
        p = self.run_ctl("llama-server.service", "enable")
        self.assertEqual(p.returncode, 2)
        self.assertEqual(self.stub_calls(), "")

    def test_missing_args_refused(self):
        for argv in ((), ("llama-server.service",), ("", "start")):
            p = self.run_ctl(*argv)
            self.assertEqual(p.returncode, 2, argv)
        self.assertEqual(self.stub_calls(), "")

    def test_uninstalled_unit_refused(self):
        # allowlisted but not installed: cat fails -> honest refusal
        # (the unit may be a system unit — never touched, parked)
        p = self.run_ctl("unsloth-warm.service", "start")
        self.assertEqual(p.returncode, 2)
        calls = self.stub_calls()
        self.assertIn("cat unsloth-warm.service", calls)  # installed check ran
        self.assertNotIn("start unsloth-warm", calls)     # but nothing else

    def test_dry_run_writes_nothing(self):
        p = self.run_ctl("llama-server.service", "start", extra={"DRY_RUN": "1"})
        self.assertEqual(p.returncode, 0)
        self.assertIn("dry-run", p.stdout + p.stderr)
        self.assertEqual(self.stub_log.read_text().splitlines()[-1].split()[1], "cat")
        self.assertFalse(self.rq_log.exists())  # no progress row

    def test_start_records_breadcrumb_and_progress_row(self):
        p = self.run_ctl("llama-server.service", "start")
        self.assertEqual(p.returncode, 0, p.stderr)
        calls = self.stub_log.read_text()
        self.assertIn("--user start llama-server.service", calls)
        self.assertIn("--user show -p ActiveState --value llama-server.service", calls)
        self.assertIn("service-ctl", self.rq_log.read_text())     # progress row
        self.assertIn("start llama-server.service", self.rq_log.read_text())
        self.assertIn("rc=0", self.rq_log.read_text())
        state = (self.tmp / "STATE.md").read_text()
        self.assertIn("service-ctl | start", state)               # breadcrumb

    def test_status_is_read_only(self):
        p = self.run_ctl("llama-server.service", "status")
        self.assertEqual(p.returncode, 0)
        self.assertIn("cat", self.stub_log.read_text())   # installed check
        self.assertNotIn("start", self.stub_log.read_text())
        self.assertFalse(self.rq_log.exists())

    def test_json_output(self):
        p = self.run_ctl("--json", "llama-server.service", "status")
        self.assertEqual(p.returncode, 0)
        self.assertIn("active_state", p.stdout)
        p = self.run_ctl("--json", "other.service", "start")
        self.assertEqual(p.returncode, 2)
        self.assertIn("refused", p.stdout)


PROBE = ROOT / "jobs" / "service-state.py"
RECOVERY = ROOT / "cadence" / "day" / "11-service-recovery.sh"


def free_port():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    p = s.getsockname()[1]
    s.close()
    return p


def listener():
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    s.listen(16)
    return s, s.getsockname()[1]


SHOW_STUB = """#!/usr/bin/env bash
# fake systemctl: logs every call; show prints fixture unit state
echo "$*" >> "$STUB_LOG"
case "$2" in
  show) printf 'ActiveState=%s\\nSubState=dead\\nUnitFileState=%s\\nExecMainStartTimestamp=\\n' "$STUB_ACTIVE" "$STUB_UNITFILE" ;;
  *) exit 0 ;;
esac
"""


class ServiceStateProbe(unittest.TestCase):
    """jobs/service-state.py retargeted to :8888 / unsloth-studio.service,
    including the serving-out-of-unit divergence classification."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.bin = self.tmp / "bin"
        self.bin.mkdir()
        self.stub_log = self.tmp / "systemctl.log"
        self.rq_log = self.tmp / "report-queue.log"
        self._install("systemctl", SHOW_STUB)
        rq = self.bin / "report-queue"
        rq.write_text(RQ_STUB)
        rq.chmod(0o755)
        self.env = dict(
            os.environ,
            HNGH_SERVICE_SYSTEMCTL=str(self.bin / "systemctl"),
            HNGH_REPORT_QUEUE=str(self.bin / "report-queue"),
            HNGH_REPORT_ROOT=str(self.tmp),
            HNGH_SERVICE_DASHBOARD=str(self.tmp / "service-state.json"),
            HNGH_SERVICE_ALERT_STAMP=str(self.tmp / ".alert-stamp"),
            HNGH_SERVICE_DIVERGENCE_STAMP=str(self.tmp / ".divergence-stamp"),
            STATE_FILE=str(self.tmp / "STATE.md"),
            STUB_LOG=str(self.stub_log),
            RQ_LOG=str(self.rq_log),
        )

    def tearDown(self):
        if getattr(self, "sock", None):
            self.sock.close()
        if getattr(self, "_late", None):
            self._late.close()

    def _install(self, name, body):
        p = self.bin / name
        p.write_text(body)
        p.chmod(0o755)

    def run_probe(self, ports, active="inactive", unitfile="enabled",
                 extra=None):
        return subprocess.run(
            ["python3", "-B", str(PROBE)],
            env=dict(self.env,
                     HNGH_SERVICE_PORTS=ports,
                     STUB_ACTIVE=active,
                     STUB_UNITFILE=unitfile,
                     **(extra or {})),
            capture_output=True, text=True, timeout=60)

    def classification(self, p):
        for line in p.stdout.splitlines():
            d = json.loads(line)
            if "classification" in d:
                return d["classification"]
        return None

    def alerts(self):
        if not self.rq_log.exists():
            return []
        return [ln for ln in self.rq_log.read_text().splitlines()
                if " alert " in ln or ln.startswith("report-queue alert")]

    def test_retargeted_constants(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("service_state", PROBE)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        self.assertEqual(mod.PORTS, [8888, 8080, 11434])
        self.assertEqual(mod.SERVING_PORT, 8888)
        self.assertEqual(mod.SERVING_UNIT, "unsloth-studio.service")
        self.assertIn("8888", mod.ALERT_TEXT)
        self.assertIn("unsloth-studio.service", mod.ALERT_TEXT)
        self.assertIn("check journal", mod.ALERT_TEXT_ACTIVE)

    def test_divergence_classified_no_alert_one_breadcrumb_per_day(self):
        self.sock, up = listener()
        for _ in range(2):  # two runs same day
            p = self.run_probe("%d,%d" % (up, free_port()))
            self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.classification(p),
                         "serving-out-of-unit (hand-launched)")
        self.assertEqual(self.alerts(), [])          # NO alert
        dash = json.loads((self.tmp / "service-state.json").read_text())
        self.assertEqual(dash["divergence"],
                         "serving-out-of-unit (hand-launched)")
        ports = {q["port"]: q["up"] for q in dash["ports"]}
        self.assertEqual(ports[up], True)
        self.assertIn("unsloth-studio.service",
                      [q["serving_unit"] for q in dash["ports"] if q["serving_unit"]])
        state = (self.tmp / "STATE.md").read_text()
        self.assertEqual(state.count("service-state | service-divergence"),
                         1)                            # day-dedup: one only

    def test_down_unit_inactive_alerts_once_per_day(self):
        down = free_port()
        for _ in range(2):
            p = self.run_probe("%d,11434" % down, active="inactive")
            self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.classification(p), "down-while-unit-inactive")
        self.assertEqual(len(self.alerts()), 1)        # day-dedup
        self.assertIn("unsloth-studio.service inactive",
                      self.alerts()[0])

    def test_down_unit_active_alert_variant_no_recovery_wording(self):
        down = free_port()
        p = self.run_probe("%d,11434" % down, active="active")
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.classification(p), "down-while-unit-active")
        self.assertEqual(len(self.alerts()), 1)
        self.assertIn("check journal", self.alerts()[0])

    def test_healthy_up_active_no_divergence_no_alert(self):
        self.sock, up = listener()
        p = self.run_probe("%d,11434" % up, active="active")
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIsNone(self.classification(p))
        self.assertEqual(self.alerts(), [])
        self.assertFalse((self.tmp / "STATE.md").exists())

    def test_dry_run_writes_nothing(self):
        self.sock, up = listener()
        p = self.run_probe("%d,11434" % up, active="inactive",
                           extra={"DRY_RUN": "1"})
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertFalse((self.tmp / "service-state.json").exists())
        self.assertFalse((self.tmp / "STATE.md").exists())
        self.assertEqual(self.alerts(), [])


class ServiceRecovery(unittest.TestCase):
    """cadence/day/11-service-recovery.sh retargeted to :8888 via
    unsloth-studio.service (the :8080/llama-server branch is gone)."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.bin = self.tmp / "bin"
        self.bin.mkdir()
        self.stub_log = self.tmp / "systemctl.log"
        self.rq_log = self.tmp / "report-queue.log"
        self.stamp = self.tmp / "recovery-stamp"
        self._install("systemctl", SHOW_STUB)
        scripts = self.tmp / "scripts"
        scripts.mkdir()
        rq = scripts / "report-queue"
        rq.write_text(RQ_STUB)
        rq.chmod(0o755)
        self.env = dict(
            os.environ,
            HNGH_SERVICE_SYSTEMCTL=str(self.bin / "systemctl"),
            HNGH_HOME=str(self.tmp),          # report-queue stub lives here
            HNGH_REPORT_ROOT=str(self.tmp),
            HNGH_SERVICE_PROBE_PORT="0",      # placeholder; set per-test
            HNGH_SERVICE_RECOVERY_SLEEP="1",
            HNGH_SERVICE_RECOVERY_STAMP=str(self.stamp),
            STATE_FILE=str(self.tmp / "STATE.md"),
            STUB_LOG=str(self.stub_log),
            RQ_LOG=str(self.rq_log),
        )

    def tearDown(self):
        if getattr(self, "sock", None):
            self.sock.close()

    def _install(self, name, body):
        p = self.bin / name
        p.write_text(body)
        p.chmod(0o755)

    def run_recovery(self, port, active="inactive", unitfile="enabled",
                     extra=None):
        return subprocess.run(
            ["bash", str(RECOVERY)],
            env=dict(self.env,
                     HNGH_SERVICE_PROBE_PORT=str(port),
                     STUB_ACTIVE=active,
                     STUB_UNITFILE=unitfile,
                     **(extra or {})),
            capture_output=True, text=True, timeout=60)

    def stub_calls(self):
        return self.stub_log.read_text() if self.stub_log.exists() else ""

    def test_retarget_to_8888_and_no_llama_server_branch(self):
        src = RECOVERY.read_text()
        self.assertIn('UNIT="unsloth-studio.service"', src)
        self.assertIn("8888", src)
        # no direct systemctl start: the ONLY start path is service-ctl.sh
        self.assertNotIn("--user start", src)

    def test_port_up_does_nothing_even_out_of_unit(self):
        self.sock, up = listener()
        p = self.run_recovery(up, active="inactive")  # divergence: up, unit dead
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertNotIn("start unsloth-studio.service", self.stub_calls())
        self.assertFalse(self.rq_log.exists())

    def test_down_inactive_starts_unit_once_per_day(self):
        down = free_port()
        # serve :8888 again during the post-start sleep => recovered path
        t = threading.Thread(target=self._serve_during_sleep, args=(down,))
        t.start()
        p = self.run_recovery(down)
        t.join()
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("--user start unsloth-studio.service", self.stub_calls())
        rq = self.rq_log.read_text()
        self.assertIn("recovered", rq)
        self.assertTrue(self.stamp.exists())          # attempt spent
        stub_before = self.stub_calls()
        p = self.run_recovery(down)                   # second run same day
        self.assertEqual(self.stub_calls(), stub_before)  # no second start

    def _serve_during_sleep(self, port):
        time.sleep(0.2)  # binds while the script sleeps before re-probe
        s = socket.socket()
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind(("127.0.0.1", port))
        s.listen(1)
        self._late = s

    def test_down_still_down_after_start_alerts_with_journal_hint(self):
        down = free_port()
        p = self.run_recovery(down)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("--user start unsloth-studio.service", self.stub_calls())
        rq = self.rq_log.read_text()
        self.assertIn("still down", rq)
        self.assertIn("journal", rq)

    def test_never_starts_active_unit(self):
        down = free_port()
        p = self.run_recovery(down, active="active")
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertNotIn("start", self.stub_calls())

    def test_uninstalled_unit_is_noop(self):
        down = free_port()
        p = self.run_recovery(down, unitfile="not-found")
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertNotIn("start", self.stub_calls())

    def test_dry_run_starts_nothing_and_keeps_attempt(self):
        down = free_port()
        p = self.run_recovery(down, extra={"DRY_RUN": "1"})
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("dry-run", p.stdout)
        self.assertNotIn("--user start", self.stub_calls())
        self.assertFalse(self.stamp.exists())  # attempt not spent
        self.assertFalse(self.rq_log.exists())


if __name__ == "__main__":
    unittest.main()
