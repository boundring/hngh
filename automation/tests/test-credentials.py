#!/usr/bin/env python3
"""lib/credentials.sh contract, hermetic.

`op` is always a stub script (HNGH_OP_BIN seam) — never the real CLI,
never the network. Contracts: cred_get prints the secret on stdout and
nothing else; any op failure (locked / missing item) exits nonzero with
EMPTY stdout and exactly one breadcrumb per UTC day (a locked vault is
an operator setup item, never an alert — credentials-posture.md §2/§4).
"""

import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

STUB = """#!/usr/bin/env bash
# test stub: read -> stub secret; whoami -> live
[ "$1" = whoami ] && exit 0
[ "$1" = read ] && { printf 'stub-secret\\n'; exit 0; }
exit 1
"""

STUB_LOCKED = """#!/usr/bin/env bash
# test stub: no live session, reads fail
[ "$1" = read ] && { echo 'locked' >&2; exit 1; }
exit 1
"""


class CredGet(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.state = self.tmp / "STATE.md"
        self.logs = self.tmp / "logs"
        self.logs.mkdir()

    def run_cred(self, stub_text, ref="op://vault/item/password"):
        stub = self.tmp / "op-stub"
        stub.write_text(stub_text)
        stub.chmod(0o755)
        script = (
            '. "%s/lib/common.sh"; . "%s/lib/breadcrumbs.sh"; '
            '. "%s/lib/credentials.sh"; cred_get "%s"'
        ) % (ROOT, ROOT, ROOT, ref)
        env = dict(os.environ, HNGH_OP_BIN=str(stub),
                   STATE_FILE=str(self.state),
                   CRED_STATE_DIR=str(self.logs))
        return subprocess.run(["bash", "-c", script], env=env,
                              capture_output=True, text=True, timeout=60)

    def crumbs(self):
        return self.state.read_text().strip().splitlines() if self.state.exists() else []

    def test_success_prints_secret_and_nothing_else(self):
        p = self.run_cred(STUB)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(p.stdout, "stub-secret\n")
        self.assertEqual(p.stderr, "")
        self.assertEqual(self.crumbs(), [])

    def test_locked_fails_closed_empty_stdout(self):
        p = self.run_cred(STUB_LOCKED)
        self.assertNotEqual(p.returncode, 0)
        self.assertEqual(p.stdout, "")
        self.assertEqual(len(self.crumbs()), 1)
        self.assertIn("1password unavailable", self.crumbs()[0])

    def test_missing_item_fails_closed(self):
        p = self.run_cred(STUB_LOCKED, ref="op://v/nope/password")
        self.assertNotEqual(p.returncode, 0)
        self.assertEqual(p.stdout, "")

    def test_one_crumb_per_utc_day_max(self):
        self.run_cred(STUB_LOCKED)
        self.run_cred(STUB_LOCKED)
        self.assertEqual(len(self.crumbs()), 1)

    def test_op_ready_reflects_session(self):
        stub_ok = self.tmp / "op-ok"
        stub_ok.write_text("#!/usr/bin/env bash\nexit 0\n")
        stub_ok.chmod(0o755)
        env = dict(os.environ, HNGH_OP_BIN=str(stub_ok),
                   STATE_FILE=str(self.state), CRED_STATE_DIR=str(self.logs))
        p = subprocess.run(
            ["bash", "-c",
             '. "%s/lib/common.sh"; . "%s/lib/credentials.sh"; op_ready' % (ROOT, ROOT)],
            env=env, capture_output=True, timeout=60)
        self.assertEqual(p.returncode, 0)


if __name__ == "__main__":
    unittest.main()
