#!/usr/bin/env python3
"""ping-hourly digest block write seam (digest mega-block writer census
2026-09-16): the news summary block (## HHMM <date> + _sources_ + model
summary) is written through lib/digest-block.sh append_news_block, the
same chokepoint family as every other digest writer, and the appended
text carries no host path tokens (/home/<user>/..., /tmp/..., ~/...).
The mega line (digest-ledger) keeps its own scrub inside the Python
builder; this shell seam re-exports digest-ledger scrub via
--scrub so the one identity seam is the only redaction definition in
the tree. Hermetic: DIGEST_DIR + HNGH_DIGESTS_DIR point at a sandbox."""

import importlib.util
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # automation/


def _load(name, rel):
    spec = importlib.util.spec_from_file_location(name, str(ROOT / rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


dl = _load("digest_ledger", "jobs/digest-ledger.py")

SEAM = ROOT / "lib" / "digest-block.sh"


class AppendNewsBlock(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.sb = Path(self._td.name)
        self.digest = self.sb / "digest"
        self.digest.mkdir(parents=True)
        self.env = dict(os.environ,
                        DIGEST_DIR=str(self.digest),
                        HNGH_DIGESTS_DIR=str(self.digest),
                        HNGH_HOME_DIR=str(self.sb / "home"))

    def tearDown(self):
        self._td.cleanup()

    def seam(self, *argv):
        return subprocess.run(
            ["bash", "-c",
             '. "%s/lib/common.sh"; . "%s"; append_news_block "$@"'
             % (ROOT, SEAM)
             + " " + " ".join('"%s"' % a for a in argv)],
            env=self.env, capture_output=True, text=True)

    def test_appends_block_shape(self):
        r = self.seam(str(self.digest / "2026-09-16.md"),
                      "2215", "2026-09-16", "kimi", "srcA,srcB", "a b")
        self.assertEqual(r.returncode, 0, r.stderr)
        text = (self.digest / "2026-09-16.md").read_text()
        self.assertIn("## 2215 2026-09-16", text)
        self.assertIn("_sources: srcA,srcB | model: kimi_", text)
        self.assertIn("a b", text)

    def test_home_path_redacted_in_summary(self):
        # the model summary is untrusted derived text; a pathy reply
        # must not ride the block into deck B / the newspaper
        r = self.seam(str(self.digest / "2026-09-16.md"), "2215",
                      "2026-09-16", "kimi", "src",
                      "log lives in /home/aubergine/store/record.lisp ok")
        self.assertEqual(r.returncode, 0, r.stderr)
        text = (self.digest / "2026-09-16.md").read_text()
        self.assertNotIn("/home/aubergine", text)
        self.assertIn("[redacted path]", text)
        self.assertIn("log lives in", text)  # redaction, not dropping

    def test_tilde_and_tmp_redacted(self):
        r = self.seam(str(self.digest / "2026-09-16.md"), "2215",
                      "2026-09-16", "local", "src",
                      "crumb token ~/dots/vimrc and /tmp/x.store")
        self.assertEqual(r.returncode, 0, r.stderr)
        text = (self.digest / "2026-09-16.md").read_text()
        self.assertNotIn("~/dots/vimrc", text)
        self.assertNotIn("/tmp/x.store", text)
        self.assertEqual(text.count("[redacted path]"), 2)


class ScrubSeam(unittest.TestCase):
    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.env = dict(os.environ)

    def tearDown(self):
        self._td.cleanup()

    def test_scrub_subcommand_matches_python_seam(self):
        """lib/digest-block.sh scrub PATH -> digest-ledger scrub_paths,
        the one identity seam for every digest writer."""
        for raw, want in [
            ("see /home/aubergine/dots/vimrc missing", "see [redacted path] missing"),
            ("token ~/x/y and /tmp/z", "token [redacted path] and [redacted path]"),
            ("url https://e.io/a stays", "url https://e.io/a stays"),
            ("plain prose", "plain prose"),
        ]:
            r = subprocess.run(
                ["bash", "-c",
                 '. "%s/lib/common.sh"; . "%s"; scrub "$1"'
                 % (ROOT, SEAM), "scrub", raw],
                env=self.env, capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertEqual(r.stdout.strip(), want, raw)
        # the same identity seam as the python builder
        self.assertEqual(
            dl.scrub_paths("see /home/aubergine/dots/vimrc missing"),
            "see [redacted path] missing")


if __name__ == "__main__":
    unittest.main()
