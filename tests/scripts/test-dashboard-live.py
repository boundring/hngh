#!/usr/bin/env python3
"""Dashboard live-mode smoke: --json, --export-html, and the session view.

The new dashboard surface: --json emits the machine-readable spine,
--export-html writes a self-contained page, and the --watch/--live loop
is the operator's foreground TUI refresh (exercised here through the
pure render path, not a real loop — an infinite loop has no test
completion). Sessions stay read-only: no store root -> empty list, and
a real store is only read through scripts/hngh present.
"""

import json
import os
import pty
import select
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = ROOT / "scripts" / "dashboard-readout"


def run(args):
    return subprocess.run([sys.executable, str(SCRIPT), *args],
                          capture_output=True, text=True, cwd=ROOT)


class DashboardExport(unittest.TestCase):
    def test_json_spine(self):
        out = run(["--json"])
        self.assertEqual(out.returncode, 0, out.stderr)
        data = json.loads(out.stdout)
        self.assertIsInstance(data["timeline"], list)
        self.assertIsInstance(data["queue"], list)
        self.assertIsInstance(data["etas"], dict)
        self.assertIn("generated", data)

    def test_export_html_writes_file(self):
        with tempfile.TemporaryDirectory() as td:
            target = Path(td) / "dash.html"
            out = run([f"--export-html={target}"])
            self.assertEqual(out.returncode, 0, out.stderr)
            html = target.read_text()
            self.assertTrue(html.startswith("<!doctype html>"))
            self.assertIn("<h2>timeline</h2>", html)
            self.assertIn("<h2>queue</h2>", html)

    def test_sessions_never_crash_without_store(self):
        import importlib.machinery
        import importlib.util
        loader = importlib.machinery.SourceFileLoader("dash_live", str(SCRIPT))
        spec = importlib.util.spec_from_loader("dash_live", loader)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        mod.STORE_ROOT = Path("/nonexistent-store")
        rows = mod.session_rows()
        self.assertIsInstance(rows, list)

    def test_quiet_with_sessions(self):
        out = run(["--quiet"])
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("session", out.stdout)

    def test_etas_stop_at_next_heading(self):
        out = run(["--json"])
        data = json.loads(out.stdout)
        self.assertIn("wake-mutation-lane", data["etas"])
        # the ETA section ends at the next '## ' heading: no interface-spec
        # or fleet lines may leak in
        for key in data["etas"]:
            self.assertFalse(key.startswith("**"),
                             f"ETA key leaked from another section: {key!r}")
            self.assertFalse(key.startswith("20"),
                             f"date line leaked into ETAs: {key!r}")

    def test_done_eta_never_drawn(self):
        out = run(["--json"])
        data = json.loads(out.stdout)
        for value in data["etas"].values():
            self.assertFalse(value.startswith("DONE"),
                             f"completed-item ETA leaked into bars: {value!r}")

    def test_theme_implies_tone(self):
        themed = run(["--theme=ocean", "--quiet"])
        plain = run(["--quiet"])
        self.assertIn("\x1b[", themed.stdout,
                      "--theme must imply ANSI tone")
        self.assertNotIn("\x1b[", plain.stdout,
                         "no theme and no --tone stays colorless")

    def test_watch_cursor_contract(self):
        p = subprocess.Popen(
            [sys.executable, str(SCRIPT), "--watch", "1"],
            stdout=subprocess.PIPE, text=True, cwd=ROOT)
        time.sleep(1.8)
        p.terminate()
        out = p.stdout.read()
        self.assertIn("\x1b[?25l", out, "watch hides the cursor")
        self.assertIn("\x1b[H\x1b[0J", out, "watch repaints in place")
        self.assertIn("updated", out, "watch shows a live status footer")
        self.assertIn("\x1b[?25h", out, "watch restores the cursor on exit")

    def _rich_present(self):
        try:
            import rich  # noqa: F401
            return True
        except ImportError:
            return False

    def test_rich_watch_renders_operative_and_quits(self):
        if not self._rich_present():
            self.skipTest("rich not installed; stdlib renderer covers the gate")
        master, slave = pty.openpty()
        p = subprocess.Popen(
            [sys.executable, str(SCRIPT), "--watch", "1"],
            stdout=slave, stderr=slave, stdin=slave, cwd=ROOT)
        out = b""
        t0 = time.time()
        while time.time() - t0 < 3.0:
            r, _, _ = select.select([master], [], [], 0.3)
            if r:
                try:
                    chunk = os.read(master, 4096)
                except OSError:
                    break
                if not chunk:
                    break
                out += chunk
        os.write(master, b"q")
        p.wait(timeout=5)
        try:
            while True:
                r, _, _ = select.select([master], [], [], 0.2)
                if not r:
                    break
                chunk = os.read(master, 4096)
                if not chunk:
                    break
                out += chunk
        except OSError:
            pass
        os.close(master)
        os.close(slave)
        text = out.decode(errors="replace")
        self.assertIn("▄▄████▄▄", text, "the operative renders")
        self.assertIn("queue runs itself", text, "header renders")
        self.assertIn("operative", text, "speech bubble renders")
        self.assertEqual(p.returncode, 0, "q quits the loop cleanly")


if __name__ == "__main__":
    unittest.main(verbosity=2)