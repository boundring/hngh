#!/usr/bin/env python3
"""Research-beat capture filter: tool-call junk never becomes doc prose.

Guard for the 2026-09-11 corpus-loss cure: 8 docs landed findings-less
because the beat wrote raw model tool-call syntax and was truncated
mid-block. Exercises lib/docfilter.py -- the filter the beat now runs on
every captured model output before it is written to digest/ or
docs/research/ -- and the empty-after-strip alert path.
"""

import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "lib"))
import docfilter

# Real corrupted-capture shape (RESEARCH-BEAT-2026-09-08-cistern-test-coverage.md),
# built from char codes so the fixture is byte-identical to the incident.
OPEN = chr(60) + "tool_call" + chr(62)
FCLOSE = chr(60) + "/function" + chr(62)
CLOSE = chr(60) + "/tool_call" + chr(62)
JUNK_BLOCK = "\n".join([
    OPEN,
    "<function=list_files>",
    "<parameter=path>",
    "/home/bricker/Projects/etc/hngh",
    "</parameter>",
    FCLOSE,
    CLOSE,
]) + "\n"


class Strip(unittest.TestCase):
    def test_complete_block_removed_prose_kept(self):
        capture = ("Grounding in the repo state.\n\n" + JUNK_BLOCK +
                   "Findings follow here.\n")
        clean = docfilter.strip_tool_calls(capture)
        self.assertNotIn("tool_call", clean)
        self.assertIn("Grounding in the repo state.", clean)
        self.assertIn("Findings follow here.", clean)

    def test_unterminated_block_removed(self):
        # A completion cut at the token cap ends mid-block: the tail must go.
        capture = ("Prose start.\n\n" + OPEN + "\n<function=Bash>\n"
                   "<parameter=command>\nls -la\n")
        self.assertEqual(docfilter.strip_tool_calls(capture), "Prose start.")

    def test_stray_fragment_lines_removed(self):
        clean = docfilter.strip_tool_calls("keep me\n</parameter>\nand me\n")
        self.assertEqual(clean, "keep me\nand me")


class Finalize(unittest.TestCase):
    def test_only_junk_returns_none(self):
        self.assertIsNone(docfilter.finalize(JUNK_BLOCK, 16000))

    def test_finish_reason_flag_adds_marker(self):
        out = docfilter.finalize("Findings body.", 16000, truncated=True)
        self.assertTrue(out.startswith("Findings body."))
        self.assertIn("[truncated at model call: completion hit the "
                      "max_tokens cap (finish_reason=length) - re-run the beat]",
                      out)

    def test_over_cap_cut_gets_explicit_marker(self):
        out = docfilter.finalize("x" * 500, 100)
        self.assertTrue(out.startswith("x" * 100))
        self.assertIn("[truncated at write: 500 chars exceeded cap 100 "
                      "- re-run the beat]", out)

    def test_no_signature_line_survives_the_filter(self):
        capture = ("Prose.\n" + JUNK_BLOCK + "<function=Bash>\nmore prose\n")
        clean = docfilter.finalize(capture, 16000)
        for line in clean.splitlines():
            self.assertIsNone(docfilter.JUNK_RE.match(line))


class Cli(unittest.TestCase):
    def test_junk_only_capture_exits_1_without_output(self):
        p = subprocess.run(
            [sys.executable, str(ROOT / "lib" / "docfilter.py"), "16000"],
            input=JUNK_BLOCK, capture_output=True, text=True)
        self.assertEqual(p.returncode, 1)
        self.assertEqual(p.stdout, "")

    def test_mixed_capture_exits_0_with_prose_and_marker(self):
        p = subprocess.run(
            [sys.executable, str(ROOT / "lib" / "docfilter.py"),
             "16000", "--truncated"],
            input="Intro.\n" + JUNK_BLOCK, capture_output=True, text=True)
        self.assertEqual(p.returncode, 0)
        self.assertTrue(p.stdout.startswith("Intro.\n"))
        self.assertIn("finish_reason=length", p.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
