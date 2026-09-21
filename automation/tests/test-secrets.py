#!/usr/bin/env python3
"""lib/secrets.py + lib/opv contract, hermetic.

`op` is always a stub script (HNGH_OP_BIN seam via credentials.sh) and
subprocess.run is mocked for the Python layer — never the real CLI,
never the network. Contracts: secret() maps env-var-style keys onto
vault item titles, caches for 900s, fails closed (raise, no plaintext
fallback); opv prints the requested field on stdout and nothing else,
exits nonzero + empty stdout on any cred_get failure.
"""

import subprocess
import sys
import tempfile
import unittest
import importlib.util
from pathlib import Path
from unittest import mock

LIB = Path(__file__).resolve().parent.parent / "lib"

_spec = importlib.util.spec_from_file_location("secrets_shim", LIB / "secrets.py")
secrets_shim = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(secrets_shim)

STUB = """#!/usr/bin/env bash
[ "$1" = read ] && { printf 'stub-secret\\n'; exit 0; }
exit 1
"""

STUB_FAIL = """#!/usr/bin/env bash
echo 'locked' >&2
exit 1
"""


class SecretPython(unittest.TestCase):
    def setUp(self):
        secrets_shim._cache.clear()

    def fake_run(self, stdout, returncode=0):
        proc = subprocess.CompletedProcess([], returncode, stdout=stdout, stderr="")
        return mock.patch.object(secrets_shim.subprocess, "run", return_value=proc)

    def test_known_key_round_trip(self):
        with self.fake_run("stub-secret\n") as run:
            self.assertEqual(secrets_shim.secret("UNSLOTH_API_KEY"), "stub-secret")
        self.assertEqual(run.call_args.args[0][2],
                         "UNSLOTH - unsloth studio local server")

    def test_cache_hit_spawns_op_once(self):
        with self.fake_run("stub-secret\n") as run:
            secrets_shim.secret("GROQ_API_KEY")
            secrets_shim.secret("GROQ_API_KEY")
        self.assertEqual(run.call_count, 1)

    def test_unknown_key_raises(self):
        with self.fake_run("x\n"):
            with self.assertRaises(KeyError):
                secrets_shim.secret("NOT_A_REAL_KEY")

    def test_op_failure_fails_closed(self):
        with self.fake_run("", returncode=1):
            with self.assertRaises(RuntimeError):
                secrets_shim.secret("DEEPSEEK_API_KEY")

    def test_empty_key_and_field_rejected(self):
        with self.assertRaises(ValueError):
            secrets_shim.secret("")
        with self.assertRaises(ValueError):
            secrets_shim.secret("GROQ_API_KEY", field="")


class OpvShell(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.stub = self.tmp / "op-stub"

    def run_opv(self, stub_text, *args):
        self.stub.write_text(stub_text)
        self.stub.chmod(0o755)
        env = dict(
            __import__("os").environ,
            HNGH_OP_BIN=str(self.stub),
            OP_SERVICE_ACCOUNT_TOKEN="test-token",
            CRED_STATE_DIR=str(self.tmp / "logs"),
            PATH="/usr/bin:/bin",
        )
        return subprocess.run(
            [str(LIB / "opv"), *args],
            capture_output=True, text=True, env=env, timeout=60)

    def test_prints_field_and_nothing_else(self):
        p = self.run_opv(STUB, "Anthropic")
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(p.stdout, "stub-secret\n")

    def test_op_failure_exits_nonzero_empty_stdout(self):
        p = self.run_opv(STUB_FAIL, "Anthropic")
        self.assertNotEqual(p.returncode, 0)
        self.assertEqual(p.stdout, "")

    def test_no_args_fails_closed(self):
        p = self.run_opv(STUB)
        self.assertNotEqual(p.returncode, 0)


if __name__ == "__main__":
    unittest.main()