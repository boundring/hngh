#!/usr/bin/env python3
"""The overnight edition gate, hermetic: window parsing (bad config
fails closed), inside/outside/wrap decisions, one-edition-per-date
idempotence, missing-digest no-op, and a full in-window dry build with
the model chain stubbed to the local leg."""
import importlib.util
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def _load(name, rel):
    spec = importlib.util.spec_from_file_location(name, str(ROOT / rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


ne = _load("newspaper_edition", "jobs/newspaper-edition.py")

DIGEST = """## 0400 2026-09-13

_sources: gdelt | model: gdelt-2.0 export (procedural ranking)_
CRITICAL: [Conflict] FIGHT FIGHT TESTLAND FIXTURE WAR ESCALATES: Two \
divisions engaged near the eastern corridor \
(https://127.0.0.1:1/war-escalates)
"""


class WindowParse(unittest.TestCase):
    def test_normal_and_wrap(self):
        self.assertEqual(ne.parse_window("01:30-06:30"), (90, 390))
        self.assertEqual(ne.parse_window("22:00-02:05"), (1320, 125))
        self.assertTrue(ne.in_window(150, ne.parse_window("01:30-06:30")))
        self.assertFalse(ne.in_window(700, ne.parse_window("01:30-06:30")))
        # wrap: 23:30 and 01:00 inside; 12:00 outside
        w = ne.parse_window("22:00-02:05")
        self.assertTrue(ne.in_window(1410, w))
        self.assertTrue(ne.in_window(60, w))
        self.assertFalse(ne.in_window(720, w))

    def test_bad_window_fails_closed(self):
        for bad in ("", "garbage", "25:00-06:30", "01:30-06:70", "01:30"):
            self.assertIsNone(ne.parse_window(bad), bad)
            ok, reason = ne.should_build("2026-09-13", "/x", bad,
                                         now_min=120)
            self.assertFalse(ok, bad)
            self.assertEqual(reason, "bad-window", bad)


class Gate(unittest.TestCase):
    DATE = "2026-09-13"

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.sb = Path(self.tmp.name)
        self.paper = self.sb / "paper"
        (ROOT / "digest")  # touch for readability of the expression below
        self.digests = self.sb / "digest"
        self.digests.mkdir()
        (self.digests / (self.DATE + ".md")).write_text(DIGEST)

    def test_outside_window_skips(self):
        ok, reason = ne.should_build(self.DATE, str(self.paper),
                                     "01:30-06:30", now_min=700)
        self.assertFalse(ok)
        self.assertEqual(reason, "outside-window")

    def test_no_digest_fails_closed(self):
        (self.digests / (self.DATE + ".md")).unlink()
        ok, reason = ne.should_build(self.DATE, str(self.paper),
                                     "01:30-06:30", now_min=120)
        self.assertFalse(ok)
        self.assertEqual(reason, "no-digest")

    def test_in_window_builds_then_idempotent(self):
        ne.DIGESTS_DIR = str(self.digests)
        ok, reason = ne.should_build(self.DATE, str(self.paper),
                                     "01:30-06:30", now_min=120)
        self.assertTrue(ok)
        self.assertEqual(reason, "build")
        marker = self.paper / self.DATE / "edition.json"
        marker.parent.mkdir(parents=True)
        marker.write_text("{}")
        ok, reason = ne.should_build(self.DATE, str(self.paper),
                                     "01:30-06:30", now_min=120)
        self.assertFalse(ok)
        self.assertEqual(reason, "already-built")


class InWindowBuild(unittest.TestCase):
    DATE = "2026-09-13"

    def test_full_build_zero_paid_calls(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        sb = Path(tmp.name)
        (sb / "jobs").mkdir()
        shutil.copytree(ROOT / "lib", sb / "lib")
        for job in ("news-articles.py", "digest-html.py",
                    "digest-local.py"):
            shutil.copy2(ROOT / "jobs" / job, sb / "jobs" / job)
        digests = sb / "digest"
        digests.mkdir(parents=True)
        (digests / (self.DATE + ".md")).write_text(DIGEST)
        paper = sb / "paper"
        stubdir = sb / "stubs"
        stubdir.mkdir()
        model_stub = stubdir / "stub-model.sh"
        model_stub.write_text(
            "#!/usr/bin/env bash\ncat >/dev/null\n"
            "echo 'The fixture war escalated another division today.'\n"
            "printf 'unsloth:stub-model' > \"$AUTOMATION_ROOT/"
            "tmp-modelused.txt\"\n"
            "printf '512' > \"$AUTOMATION_ROOT/tmp-tokensin.txt\"\n"
            "printf '128' > \"$AUTOMATION_ROOT/tmp-tokensout.txt\"\n")
        img_stub = stubdir / "stub-imagegen.sh"
        img_stub.write_text(
            "#!/usr/bin/env bash\nout=; while [ $# -gt 0 ]; do "
            "case $1 in --out-dir) out=$2; shift 2;; *) shift;; esac; done\n"
            "p=\"$out/stub.png\"; printf x > \"$p\"; echo \"wrote $p\"\n")
        img_stub.chmod(0o755)
        model_stub.chmod(0o755)
        env = dict(os.environ,
                   HNGH_AUTOMATION_ROOT=str(sb),
                   HNGH_NEWSPAPER_DIR=str(paper),
                   HNGH_DIGESTS_DIR=str(digests),
                   STATE_FILE=str(sb / "STATE.md"),
                   HNGH_NEWSPAPER_WINDOW="01:30-06:30",
                   HNGH_NEWSPAPER_NOW="120",
                   NEWS_ARTICLES_MODEL_CMD='bash "%s"' % model_stub,
                   NEWS_ARTICLES_IMAGEGEN_CMD=str(img_stub),
                   NEWS_ARTICLES_FETCH="0", MODEL_PIN="local",
                   UNSLOTH_URL="", KIMI_URL="")
        r = subprocess.run(
            [sys.executable, "-B", str(ROOT / "jobs/newspaper-edition.py"),
             self.DATE], capture_output=True, text=True, timeout=120,
            env=env)
        self.assertEqual(r.returncode, 0, r.stderr)
        edition = paper / self.DATE
        meta = json.loads((edition / "edition.json").read_text())
        self.assertEqual(meta["status"], "full")
        self.assertEqual(meta["paid_calls"], 0)
        self.assertEqual(meta["model_sessions"], 1)
        self.assertEqual(meta["tokens_in"], 512)
        self.assertEqual(meta["tokens_out"], 128)
        self.assertEqual(meta["window"], "01:30-06:30")
        self.assertTrue((edition / "digest.md").is_file())
        self.assertTrue((edition / "index.html").is_file())
        self.assertTrue(list(edition.glob("*.md")))


if __name__ == "__main__":
    sys.exit(0 if unittest.main(exit=False).result.wasSuccessful() else 1)
