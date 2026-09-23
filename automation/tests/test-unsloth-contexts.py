#!/usr/bin/env python3
"""unsloth-contexts registry, hermetic (fixture cards, no network).

Contract: extract_contexts pulls (native, max_extended) out of real card
phrasing, the fixture emit path writes a well-formed TSV with per-row
columns, and non-context models (image/ASR repos) resolve to empty fields
rather than guesses."""

import contextlib
import importlib.util
import io
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

# Real 30m-tick failure shape: HF hub-cache snapshot path, filename carries
# variant+quant suffix (2026-09-23 defect cleanup).
ORNITH_SNAPSHOT = (
    "~/.cache/huggingface/hub/models--unsloth--"
    "Ornith-1.0-9B-GGUF/snapshots/a674c5a128bb74049b1bb3619f1355073db5b48c"
    "/Ornith-1.0-9B-UD-Q4_K_XL.gguf")


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


class ObserveTest(unittest.TestCase):
    def setUp(self):
        # hermetic: no journal reads, no live 400 probe
        self._orig = (uc._local_api, uc.journal_n_ctx, uc.probe_400)
        uc.journal_n_ctx = lambda: (None, None)
        uc.probe_400 = lambda: None

    def tearDown(self):
        uc._local_api, uc.journal_n_ctx, uc.probe_400 = self._orig

    def _tsv(self, d):
        p = os.path.join(d, "r.tsv")
        open(p, "w").write(
            "model_id\tserver_observed\tcard_native\tcard_max_extended\t"
            "source_url\tchecked_at\n"
            "unsloth/Qwen3.8-27B-GGUF\t262144\t262144\t1000000\thttps://x\t2026-09-13\n"
            "unsloth/Ornith-1.0-9B-GGUF\t\t131072\t\thttps://z\t2026-09-22\n"
            "unsloth/Z-Image-Turbo-unsloth-bnb-4bit\t\t\t\thttps://y\t2026-09-13\n")
        return p

    def test_match_row_longest_suffix(self):
        rows = [["unsloth/Qwen3.8-27B-GGUF"],
                ["unsloth/Z-Image-Turbo-unsloth-bnb-4bit"]]
        self.assertEqual(uc.match_row(rows, "unsloth/Qwen3.8-27B-GGUF:UD-Q2_K_XL"), 0)
        self.assertEqual(uc.match_row(rows, "unsloth/Qwen3.8-27B-GGUF"), 0)
        self.assertIsNone(uc.match_row(rows, "other/vendor-1B-GGUF"))

    def test_observe_loaded_updates_row(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._tsv(d)
            uc._local_api = lambda path: {
                "loaded": True, "active_model": "unsloth/Qwen3.8-27B-GGUF:UD-Q2_K_XL",
                "max_context_length": 102400, "context_length": 102400}
            self.assertEqual(uc.observe(p), 0)
            row = [l.split("\t") for l in open(p).read().splitlines()][1]
            self.assertEqual(row[1], "102400")
            self.assertEqual(row[5], uc.datetime.date.today().isoformat())

    def test_observe_hf_cache_path_resolves_row(self):
        # active_model is a GGUF snapshot FILE path (variant+quant suffix);
        # the row lookup must map models--ORG--NAME -> ORG/NAME instead of
        # matching a file path against id-keyed rows (2026-09-23 defect
        # cleanup: 30m ticks logged "no registry row matches" every beat).
        with tempfile.TemporaryDirectory() as d:
            p = self._tsv(d)
            err = io.StringIO()
            uc._local_api = lambda path: {
                "loaded": True, "active_model": ORNITH_SNAPSHOT,
                "max_context_length": 131072, "context_length": 131072}
            with contextlib.redirect_stderr(err):
                self.assertEqual(uc.observe(p), 0)
            rows = [l.split("\t") for l in open(p).read().splitlines()]
            self.assertEqual(rows[2][0], "unsloth/Ornith-1.0-9B-GGUF")
            self.assertEqual(rows[2][1], "131072")
            self.assertEqual(rows[2][5], uc.datetime.date.today().isoformat())
            self.assertNotIn("no registry row matches", err.getvalue())

    def test_observe_unknown_path_breadcrumbs_once(self):
        # fail-open intact: an unresolvable ref is reported exactly once and
        # never guessed into a row (2026-09-23 defect cleanup).
        with tempfile.TemporaryDirectory() as d:
            p = self._tsv(d)
            before = open(p).read()
            err = io.StringIO()
            uc._local_api = lambda path: {
                "loaded": True, "active_model": (
                    "~/.cache/huggingface/hub/models--unsloth--"
                    "Mystery-3B-GGUF/snapshots/deadbeef"
                    "/Mystery-3B-UD-Q4_K_XL.gguf"),
                "max_context_length": 8192, "context_length": 8192}
            with contextlib.redirect_stderr(err):
                self.assertEqual(uc.observe(p), 0)
            self.assertEqual(open(p).read(), before)
            self.assertEqual(
                err.getvalue().count("no registry row matches"), 1)

    def test_observe_api_id_preferred_over_path(self):
        # served id from /api/inference/status wins over the path mapping
        # (2026-09-23 defect cleanup).
        with tempfile.TemporaryDirectory() as d:
            p = self._tsv(d)
            err = io.StringIO()
            uc._local_api = lambda path: {
                "loaded": True,
                "model_identifier": "unsloth/Qwen3.8-27B-GGUF:UD-Q2_K_XL",
                "active_model": ORNITH_SNAPSHOT,
                "max_context_length": 102400, "context_length": 102400}
            with contextlib.redirect_stderr(err):
                self.assertEqual(uc.observe(p), 0)
            rows = [l.split("\t") for l in open(p).read().splitlines()]
            self.assertEqual(rows[1][1], "102400")  # id match -> Qwen row
            self.assertEqual(rows[2][1], "")        # path mapping not used
            self.assertNotIn("no registry row matches", err.getvalue())

    def test_observe_unloaded_noop(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._tsv(d)
            before = open(p).read()
            uc._local_api = lambda path: {
                "loaded": False, "active_model": None,
                "max_context_length": None, "context_length": None}
            self.assertEqual(uc.observe(p), 0)
            self.assertEqual(open(p).read(), before)

    def test_observe_skips_probe_when_registry_known(self):
        # hngh-bud: journal gives the model path but no n_ctx line; the
        # registry row already holds a server_observed value -> no 400
        # probe (the probe processed ~4.4 min of GPU instead of failing).
        with tempfile.TemporaryDirectory() as d:
            p = self._tsv(d)
            before = open(p).read()
            uc._local_api = lambda path: (_ for _ in ()).throw(
                OSError("down"))
            uc.journal_n_ctx = lambda: (
                "/models/unsloth_Qwen3.8-27B-GGUF-Q4.gguf", None)
            uc.probe_400 = lambda: (_ for _ in ()).throw(
                AssertionError("probe_400 must not run"))
            self.assertEqual(uc.observe(p), 0)
            self.assertEqual(open(p).read(), before)


class ProbePayloadTest(unittest.TestCase):
    def test_probe_guaranteed_oversized_and_bounded(self):
        # hngh-bud: "a " * 150000 (~147k tokens) FITS the studio's
        # 262144 context, so the server processed it (4.4 min GPU)
        # instead of returning 400. The payload must exceed the largest
        # registry context (card_max_extended 1048576) and bound cost.
        payload = uc.probe_payload()
        self.assertGreaterEqual(
            payload["messages"][0]["content"].count("a"), 1_200_000)
        self.assertEqual(payload["max_tokens"], 1)

    def test_probe_short_timeout(self):
        captured = {}
        def fake_urlopen(req, timeout=None):
            captured["timeout"] = timeout
            raise uc.urllib.error.HTTPError(
                req.full_url, 400, "ctx",
                hdrs=None, fp=io.BytesIO(b"n_ctx = 262144"))
        orig = uc.urllib.request.urlopen
        uc.urllib.request.urlopen = fake_urlopen
        try:
            self.assertEqual(uc.probe_400(), 262144)
        finally:
            uc.urllib.request.urlopen = orig
        self.assertIsNotNone(captured["timeout"])
        self.assertLessEqual(captured["timeout"], 10)


if __name__ == "__main__":
    unittest.main()
