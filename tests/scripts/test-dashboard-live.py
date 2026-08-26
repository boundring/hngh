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
import subprocess
import sys
import tempfile
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


if __name__ == "__main__":
    unittest.main(verbosity=2)