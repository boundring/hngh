#!/usr/bin/env python3
"""unsloth-contexts registry, hermetic (fixture cards, no network).

Contract: extract_contexts pulls (native, max_extended) out of real card
phrasing, the fixture emit path writes a well-formed TSV with per-row
columns, and non-context models (image/ASR repos) resolve to empty fields
rather than guesses."""

import importlib.util
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
JOB = ROOT / "jobs" / "unsloth-contexts.py"

spec = importlib.util.spec_from_file_location("uc", JOB)
uc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(uc)


CARDS = {
    "unsloth/Qwen3.8-27B-GGUF.txt":
        "Context length of 262144. Supports 1M context with YaRN.",
    "unsloth/Ornith-1.0-9B-GGUF.txt":
        "Native context length of 131072 tokens.",
    "unsloth/Z-Image-Turbo-unsloth-bnb-4bit.txt":
        "A 6B step-distilled diffusion model for image generation.",
}


class ExtractTest(unittest.TestCase):
    def test_native_plus_yarn(self):
        self.assertEqual(uc.extract_contexts(CARDS[
            "unsloth/Qwen3.8-27B-GGUF.txt"]), (262144, 1048576))

    def test_native_only(self):
        self.assertEqual(uc.extract_contexts(CARDS[
            "unsloth/Ornith-1.0-9B-GGUF.txt"]), (131072, None))

    def test_non_context_model_unresolved(self):
        self.assertEqual(uc.extract_contexts(CARDS[
            "unsloth/Z-Image-Turbo-unsloth-bnb-4bit.txt"]), (None, None))

    def test_trained_with_kmb(self):
        n, e = uc.extract_contexts(
            "Trained with 40K context, extended to 128K via RoPE scaling.")
        self.assertEqual((n, e), (40960, 131072))


class FixtureEmitTest(unittest.TestCase):
    def test_tsv_wellformed(self):
        with tempfile.TemporaryDirectory() as d:
            for name, text in CARDS.items():
                p = Path(d) / name
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(text)
            tsv = os.path.join(d, "out.tsv")
            # point the job at the fixture dir via subprocess, capture TSV
            r = subprocess.run(
                [sys.executable, str(JOB), "--fixture", d, "--out", tsv],
                check=True,
                capture_output=True, text=True, env={**os.environ})
            tsv_text = Path(tsv).read_text()
        lines = tsv_text.strip().split("\n")
        self.assertEqual(lines[0].split("\t"),
                         ["model_id", "server_observed", "card_native",
                          "card_max_extended", "source_url", "checked_at"])
        rows = {l.split("\t")[0]: l.split("\t") for l in lines[1:]}
        self.assertEqual(rows["unsloth/Qwen3.8-27B-GGUF"][2], "262144")
        self.assertEqual(rows["unsloth/Qwen3.8-27B-GGUF"][3], "1048576")
        self.assertEqual(rows["unsloth/Ornith-1.0-9B-GGUF"][2], "131072")
        self.assertEqual(rows["unsloth/Z-Image-Turbo-unsloth-bnb-4bit"][2], "")


if __name__ == "__main__":
    unittest.main()
