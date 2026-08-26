#!/usr/bin/env python3
"""Fleet-manager smoke: honest offline behavior and the wake guard.

The discover path must work with no mesh, no credentials, and no
network: a logged-out tailscale daemon produces the honest line and
exit 0. --json must always emit a parseable doc. The wake guard is the
safety contract: an unpinned or malformed MAC refuses (exit 1) without
touching a socket; a valid MAC path is exercised through a mocked
socket so the suite never emits packets.
"""

import importlib.machinery
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = ROOT / "scripts" / "fleet-manager"


def load():
    loader = importlib.machinery.SourceFileLoader("fleet_mod", str(SCRIPT))
    spec = importlib.util.spec_from_loader("fleet_mod", loader)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def run(args):
    return subprocess.run([sys.executable, str(SCRIPT), *args],
                          capture_output=True, text=True, cwd=ROOT)


class FleetGuard(unittest.TestCase):
    def test_discover_offline_is_honest(self):
        out = run(["--discover"])
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("no tailscale peers", out.stdout)

    def test_json_parses_offline(self):
        out = run(["--json"])
        self.assertEqual(out.returncode, 0, out.stderr)
        data = json.loads(out.stdout)
        self.assertIn("nodes", data)

    def test_wake_unpinned_refuses(self):
        mod = load()
        with tempfile.TemporaryDirectory() as td:
            mod.FLEET_FACTS = Path(td) / "fleet.md"
            sent, refusal = mod.wake_peer("steam-deck", mod.fleet_macs())
            self.assertIsNone(sent)
            self.assertIn("no MAC", refusal)

    def test_wake_malformed_mac_refuses(self):
        mod = load()
        sent, refusal = mod.wake_peer("x", {"x": "zz-not-a-mac"})
        self.assertIsNone(sent)
        self.assertIn("malformed", refusal)

    def test_wake_valid_mac_sends_bounded(self):
        mod = load()
        sent_log = []

        class FakeSocket:
            def setsockopt(self, *a):
                pass

            def sendto(self, data, addr):
                sent_log.append((data, addr))
                return len(data)

            def close(self):
                pass

        with mock.patch.object(mod.socket, "socket", return_value=FakeSocket()):
            sent, refusal = mod.wake_peer("deck", {"deck": "aa:bb:cc:dd:ee:ff"})
        self.assertIsNone(refusal)
        self.assertTrue(sent)
        self.assertTrue(any("sent" in s for s in sent))
        self.assertTrue(all(len(p[0]) == 102 for p in sent_log))  # 6+12+6*16 bytes

    def test_record_writes_only_docs(self):
        mod = load()
        with tempfile.TemporaryDirectory() as td:
            mod.FLEET_FACTS = Path(td) / "fleet.md"
            mod.QUEUE = Path(td) / "queue.md"
            mod.record_fleet([], {"date": "2026-08-26", "audio": 0,
                                  "tailscale": "logged-out",
                                  "dbus": "unavailable"})
            self.assertIn("observed", mod.FLEET_FACTS.read_text())
            self.assertIn("Fleet observation", mod.QUEUE.read_text())


if __name__ == "__main__":
    unittest.main(verbosity=2)