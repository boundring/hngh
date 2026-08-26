#!/usr/bin/env python3
"""dashboard-tui smoke: the full-screen textual watch.

Textual is optional (a real user-site dependency, not a repo dep), so
the suite degrades gracefully: the no-textual path is always asserted,
and the live PTY smoke runs only when textual is importable. Kept
robust — the PTY run is let alone for ~4s, captured, then SIGTERMed,
and any of 0/-15/143 counts as a clean exit.
"""

import os
import pty
import select
import subprocess
import sys
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPT = ROOT / "scripts" / "dashboard-tui"


def textual_present():
    try:
        import textual  # noqa: F401
        return True
    except ImportError:
        return False


def run_env(env):
    full = dict(os.environ)
    full.update(env)
    return subprocess.run([sys.executable, str(SCRIPT)],
                          capture_output=True, text=True, cwd=ROOT,
                          env=full)


class DashboardTUI(unittest.TestCase):
    def test_help_exits_zero(self):
        out = subprocess.run([sys.executable, str(SCRIPT), "--help"],
                             capture_output=True, text=True, cwd=ROOT)
        self.assertEqual(out.returncode, 0, out.stderr)
        self.assertIn("full-screen", out.stdout)

    def test_no_textual_exits_two_with_hint(self):
        out = run_env({"HNGH_NO_TEXTUAL": "1"})
        self.assertEqual(out.returncode, 2, out.stdout)
        self.assertIn("textual not available", out.stderr)
        self.assertIn("pip install", out.stderr)

    @unittest.skipUnless(textual_present(), "textual not importable")
    def test_pty_renders_and_quits_cleanly(self):
        pid, fd = pty.fork()
        if pid == 0:
            os.execvp(sys.executable,
                      [sys.executable, str(SCRIPT), "--interval", "1"])
        try:
            def snapshot(seconds):
                data = b""
                deadline = time.time() + seconds
                while time.time() < deadline:
                    r, _, _ = select.select([fd], [], [], 1)
                    if not r:
                        continue
                    try:
                        chunk = os.read(fd, 65536)
                    except OSError:
                        break
                    if not chunk:
                        break
                    data += chunk
                return data.decode("utf-8", "replace")

            # first render settles in; the operative head glyph (a v2
            # frame fragment) is shared by every frame, so it is a stable
            # presence check for the operative panel.
            first = snapshot(2.2)
            self.assertIn("▄█████▄", first, "operative figure renders")
            self.assertIn("hngh", first, "header renders")
            self.assertIn("queue", first, "queue table renders")
            self.assertIn("sessions", first, "sessions table renders")

            # frame cycling: a later read still shows the figure and the
            # screen moved on (operative animation + live data tick), so
            # the operative is not a frozen still.
            second = snapshot(1.6)
            self.assertIn("▄█████▄", second, "figure persists across frames")
            self.assertNotEqual(first, second, "animation cycles")
        finally:
            try:
                os.kill(pid, 15)
            except (OSError, ProcessLookupError):
                pass
            _, rc = os.waitpid(pid, 0)
        self.assertIn(os.waitstatus_to_exitcode(rc),
                      (0, -15, 143),
                      f"clean exit, got {rc}")


if __name__ == "__main__":
    unittest.main(verbosity=2)