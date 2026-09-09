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


if __name__ == "__main__":
    unittest.main()
