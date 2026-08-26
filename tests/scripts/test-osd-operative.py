#!/usr/bin/env python3
"""osd-operative guard: the OSD feeder writes a snapshot JSON, fail-closed.

The desktop overlay's data layer is a foreground feeder that writes a
snapshot JSON for the qml6 window to poll. This suite asserts the
contract the overlay depends on:

- --help exits 0 and documents the qml6 invocation.
- --once writes a parseable snapshot with the expected keys, "ok": true,
  exactly 4 operative frames, and a backlog summary.
- A broken data source (the operative frame generator fails) fails
  closed: the feeder still writes a document, but with "ok": false and a
  plain message — it never crashes.

The .qml window itself is verified live (X11), not under unittest.
"""

import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = ROOT / "scripts" / "osd-operative"

EXPECTED_KEYS = {
    "ts", "queue_queued", "queue_done", "backlog",
    "speech", "status", "frames", "ok",
}
BACKLOG_KEYS = {"total", "done", "queued", "open", "in_queue"}


def run(args, env_extra=None):
    env = dict(os.environ)
    env.update(env_extra or {})
    return subprocess.run([sys.executable, str(SCRIPT), *args],
                          capture_output=True, text=True, cwd=ROOT, env=env)


def load_module():
    loader = importlib.machinery.SourceFileLoader("osd_operative", str(SCRIPT))
    spec = importlib.util.spec_from_loader("osd_operative", loader)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class OsdOperative(unittest.TestCase):
    def test_help_exits_zero_and_documents_qml6(self):
        out = run(["--help"])
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("qml6 scripts/osd-operative.qml", out.stdout)

    def test_once_writes_snapshot_with_expected_keys(self):
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "osd.json"
            out = run(["--once"], {"HNGH_OSD_OUT": str(target)})
            self.assertEqual(out.returncode, 0, out.stderr)
            self.assertTrue(target.exists(), f"no snapshot at {target}")
            data = json.loads(target.read_text())
            self.assertTrue(data["ok"])
            self.assertTrue(EXPECTED_KEYS.issubset(data.keys()))
            self.assertIsInstance(data["ts"], int)
            self.assertEqual(len(data["frames"]), 4)
            self.assertTrue(all(isinstance(f, str) and f
                                for f in data["frames"]))
            self.assertTrue(BACKLOG_KEYS.issubset(data["backlog"].keys()))
            self.assertIsInstance(data["speech"], str)
            self.assertTrue(data["speech"])
            self.assertIsInstance(data["status"], str)
            self.assertIn("queue", data["status"])
            self.assertIn("lanes", data["status"])

    def test_broken_data_fails_closed(self):
        # Make the frame generator fail: a broken-source scenario the
        # feeder must survive with "ok": false and a plain message.
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "osd.json"
            mod = load_module()
            mod.OUT_PATH = target
            mod.EVOLVE = [sys.executable, "-c", "raise SystemExit(1)"]
            rc = mod.main(["--once"])
            self.assertEqual(rc, 1)
            self.assertTrue(target.exists(), f"no snapshot at {target}")
            data = json.loads(target.read_text())
            self.assertFalse(data["ok"])
            self.assertIn("msg", data)
            self.assertIn("frames", data["msg"])


if __name__ == "__main__":
    unittest.main(verbosity=2)