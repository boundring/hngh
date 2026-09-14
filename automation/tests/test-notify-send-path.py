#!/usr/bin/env python3
"""notify send-path proof, hermetic.

1. fail-closed: conf present, [1password] item set, op stub fails, conf
   pass empty -> scripts/notify-email.py exits 2 before any SMTP attempt;
   lib/notify-email.sh email_sidechannel records 'send failed rc=2' in the
   seamed HNGH_NOTIFY_EMAIL_LOG. No send performed (the exit-2 path is
   before send()).
2. seam dispatch: lib/notify.sh notify_event with telegram/webhook armed ->
   stub curl on PATH captures the request construction (payload + [TEST]
   label); no real network, no real endpoint, no credential values.

Env seams used: HNGH_NOTIFY_EMAIL_CONF, HNGH_OP_BIN, HNGH_NOTIFY_EMAIL_LOG
(log path seam added to lib/notify-email.sh), HNGH_NOTIFY_STAMP_DIR,
HNGH_NOTIFY_MIN_INTERVAL, STATE_FILE.
"""

import os
import shlex
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
NOTIFY = ROOT / "scripts" / "notify-email.py"

# conf WITH a 1password item but an EMPTY pass: op failure must fail closed.
CONF_FAILCLOSED = """[smtp]
host = 127.0.0.1
port = 1
user = test
pass =
from = test@example.invalid
to = op@example.invalid
[1password]
item = op://vault/item/field
"""

OP_FAIL = "#!/bin/sh\nexit 1\n"


def write_file(path, text, mode=0o600):
    path.write_text(text)
    path.chmod(mode)
    return path


class SendPathBase(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.sb = Path(tmp.name)
        self.log = self.sb / "notify-email.log"
        self.state = self.sb / "STATE.md"
        self.conf = write_file(self.sb / "notify-email.conf", CONF_FAILCLOSED)
        self.op = write_file(self.sb / "op-fail", OP_FAIL, 0o755)
        self.env = {
            **os.environ,
            "HNGH_OP_BIN": str(self.op),
            "HNGH_NOTIFY_EMAIL_CONF": str(self.conf),
            "HNGH_NOTIFY_EMAIL_LOG": str(self.log),
            "STATE_FILE": str(self.state),
            "AUTOMATION_ROOT": str(ROOT),
        }

    def bash(self, script):
        return subprocess.run(["bash", "-c", script], env=self.env,
                              capture_output=True, text=True, timeout=60)


class FailClosed(SendPathBase):
    """conf present, no usable pass, op unavailable -> rc=2, log line, no send."""

    def test_script_rc2(self):
        r = subprocess.run(
            ["python3", str(NOTIFY), "send", "--subject", "[TEST] probe",
             "--body-text", "probe body"],
            env=self.env, capture_output=True, text=True, timeout=60)
        self.assertEqual(r.returncode, 2)
        self.assertIn("no password available", r.stderr)
        self.assertIn("fail closed", r.stderr)

    def test_sidechannel_logs_rc2(self):
        r = self.bash(
            '. "%s/breadcrumbs.sh"; . "%s/notify-email.sh"\n'
            'email_sidechannel "[TEST] send-path probe" "probe body"\n'
            'printf "rc=%%d" $?\n' % (LIB, LIB))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("rc=0", r.stdout)  # sidechannel never fails the caller
        log = self.log.read_text()
        self.assertIn("send failed rc=2", log)
        self.assertIn("1password unavailable", log)
        # one failure row (stderr embeds a newline, so count the rows)
        self.assertEqual(
            sum(1 for ln in log.splitlines() if "send failed rc=" in ln), 1)


CURL_STUB = """#!/bin/sh
printf '%s\\n' "$*" >> "$CURL_LOG"
printf '200'
"""


class SeamDispatch(SendPathBase):
    """notify_event routes to telegram/webhook; payload captured by stub curl;
    [TEST] label travels in the request; no network, no secret in output."""

    def setUp(self):
        super().setUp()
        self.bin = self.sb / "bin"
        self.bin.mkdir()
        write_file(self.bin / "curl", CURL_STUB, 0o755)
        self.curl_log = self.sb / "curl.log"
        self.env.update({
            "PATH": "%s:%s" % (self.bin, self.env["PATH"]),
            "CURL_LOG": str(self.curl_log),
            "HNGH_NOTIFY_STAMP_DIR": str(self.sb / "stamps"),
            "HNGH_NOTIFY_MIN_INTERVAL": "60",
        })

    def seam(self, env_pairs):
        exports = "".join("export %s=%s\n" % (k, shlex.quote(v))
                          for k, v in env_pairs)
        return self.bash(
            'breadcrumb() { :; }\n' + exports +
            '. "%s/notify.sh"\n'
            'notify_event test "[TEST] hngh seam probe" "probe body"\n'
            'printf "rc=%%d" $?\n' % LIB)

    def test_webhook(self):
        r = self.seam([("HNGH_WEBHOOK_URL", "http://127.0.0.1:1/hook")])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("rc=0", r.stdout)
        payload = self.curl_log.read_text()
        self.assertIn("http://127.0.0.1:1/hook", payload)
        self.assertIn('"class": "test"', payload)
        self.assertIn('"subject": "[TEST] hngh seam probe"', payload)
        self.assertIn('"ts"', payload)
        # stub curl is the only transport: argv log + HTTP 200, no network.

    def test_telegram(self):
        r = self.seam([("TELEGRAM_BOT_TOKEN", "stub-token-never-real"),
                       ("TELEGRAM_CHAT_ID", "12345")])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("rc=0", r.stdout)
        payload = self.curl_log.read_text()
        self.assertIn("chat_id=12345", payload)
        self.assertIn("[TEST] hngh seam probe", payload)
        self.assertNotIn("stub-token-never-real", r.stdout + r.stderr)


SMTP_SINK = '''#!/usr/bin/env python3
# minimal loopback SMTP sink: enough conversation for smtplib
# (EHLO-capability line, AUTH LOGIN, MAIL/RCPT/DATA, QUIT). Deliberately
# does NOT advertise STARTTLS so the client takes its plain-relay path.
# All CRLFs are built via bytes((13, 10)) - no escape literals - so the
# template cannot double-escape anything.
import socket, sys, threading

PORT = %(port)d
LOG = r"%(sinklog)s"
CRLF = bytes((13, 10))

def serve():
    srv = socket.socket()
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", PORT))
    srv.listen(1)
    with open(LOG.replace("sink.log", "ready"), "w") as fh:
        fh.write("ready")
    while True:
        conn, _ = srv.accept()
        f = conn.makefile("rwb")
        f.write(b"220 sink ready" + CRLF); f.flush()
        data_mode = False
        while True:
            line = f.readline()
            if not line:
                break
            line = line.rstrip(CRLF)
            with open(LOG, "ab") as lh:
                lh.write(line + bytes((10,)))
            if data_mode:
                if line == b".":
                    data_mode = False
                    f.write(b"250 ok" + CRLF)
                else:
                    continue
            elif line.upper().startswith(b"EHLO"):
                f.write(b"250-sink" + CRLF + b"250 AUTH LOGIN" + CRLF)
            elif line.upper().startswith(b"AUTH"):
                tokens = line.split()
                if len(tokens) >= 3:  # initial-response: password only
                    f.write(b"334 UGFzc3dvcmQ6" + CRLF)  # "Password:"
                    f.flush()
                    f.readline()
                else:  # two-challenge: Username then Password
                    f.write(b"334 VXNlcm5hbWU6" + CRLF)  # "Username:"
                    f.flush()
                    f.readline()
                    f.write(b"334 UGFzc3dvcmQ6" + CRLF)  # "Password:"
                    f.flush()
                    f.readline()
                with open(LOG, "ab") as lh:
                    lh.write(b"<auth>" + bytes((10,)))
                f.write(b"235 ok" + CRLF)
            elif line.upper().startswith(b"DATA"):
                data_mode = True
                f.write(b"354 go" + CRLF)
            elif line.upper().startswith(b"QUIT"):
                f.write(b"221 bye" + CRLF)
                f.flush()
                break
            else:
                f.write(b"250 ok" + CRLF)
            f.flush()
        conn.close()
'''



class SuccessSend(SendPathBase):
    """A SUCCESSFUL send must be recorded: lib/notify-email.sh
    email_sidechannel writes exactly one 'send ok rc=0' row into the
    seamed log (jobs/patrol.py check_email_sends greps that format from
    notify-email.log). Hermetic: a loopback SMTP sink stands in for the
    real relay; the conf pass is a dummy, no real credential, no network."""

    @classmethod
    def setUpClass(cls):
        import time
        import threading
        tmp = tempfile.mkdtemp()
        cls.sink_log = Path(tmp) / "sink.log"
        ns = {}
        prog = SMTP_SINK % {"port": 8587, "sinklog": cls.sink_log}
        exec(compile(prog, "smtp-sink", "exec"), ns)
        cls.thread = threading.Thread(target=ns["serve"], daemon=True)
        cls.thread.start()
        ready = cls.sink_log.parent / "ready"
        for _ in range(50):
            if ready.exists():
                break
            time.sleep(0.1)
        else:  # the sink never bound: raise loudly so failures are visible
            raise RuntimeError("smtp sink failed to bind on 8587")

    @classmethod
    def tearDownClass(cls):
        pass  # daemon thread dies with the test process

    def setUp(self):
        super().setUp()
        # conf WITH conf-pass fallback (op stub fails -> conf pass is used)
        # and pointed at the loopback sink
        self.conf.write_text(
            CONF_FAILCLOSED.replace("pass =\n", "pass = dummy-sink-pass\n")
                           .replace("port = 1", "port = 8587"))
        self.env["HNGH_NOTIFY_EMAIL_CONF"] = str(self.conf)

    def test_success_send_logged(self):
        r = self.bash(
            '. "%s/breadcrumbs.sh"; . "%s/notify-email.sh"\n'
            'email_sidechannel "[TEST] hngh send-path proof" "proof body"\n'
            'printf "rc=%%d" $?\n' % (LIB, LIB))
        self.assertEqual(r.returncode, 0, r.stderr)
        log = self.log.read_text()
        self.assertIn("send ok rc=0", log)
        self.assertEqual(
            sum(1 for ln in log.splitlines() if "send ok rc=0" in ln), 1)
        sink = self.sink_log.read_bytes() if self.sink_log.exists() else b""
        # smtplib verb casing varies by Python (3.12 sends "rcpt TO:")
        self.assertIn(b"rcpt to:", sink.lower())  # SMTP really delivered
        self.assertNotIn(b"dummy-sink-pass", log.encode())  # no secret in log


if __name__ == "__main__":
    unittest.main()
