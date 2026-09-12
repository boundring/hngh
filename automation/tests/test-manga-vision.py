#!/usr/bin/env python3
"""manga-vision P0, hermetic: fixture pages + stubbed VISION_CALL.
No network, no collection, no real model. Provenance: nothing extracted
outside a temp dir; lessons JSON asserted, never pixels."""
import importlib.util
import json
import os
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def _load(name, rel):
    spec = importlib.util.spec_from_file_location(name, str(ROOT / rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


mv = _load("manga_vision", "jobs/manga-vision.py")

STUB_REPLY = json.dumps({
    "panel_flow": "tall establishing panel then rapid strips",
    "reading_order": "right-to-left",
    "narrative_mode": "image-only",
    "dialogue_elements": "none",
    "imagery_carries": "descent into the structure, scale by silhouette",
    "page_turn_hook": "cliff: a light appears at page bottom",
})


def _fixture_cbz(tmp, n=8):
    """Synthetic white pages with two black panels each -> cbz."""
    pages = []
    for i in range(n):
        p = os.path.join(tmp, "p%03d.png" % i)
        subprocess.run(
            ["magick", "-size", "400x600", "canvas:white",
             "-fill", "black", "-draw", "rectangle 20,20 180,280",
             "-draw", "rectangle 220,20 380,280", "png:" + p],
            check=True, capture_output=True)
        pages.append(p)
    cbz = os.path.join(tmp, "fixture.cbz")
    with zipfile.ZipFile(cbz, "w") as z:
        for p in pages:
            z.write(p, os.path.basename(p))
    return cbz


def _stub(prompt, paths, timeout=300):
    assert len(paths) == 2
    for p in paths:
        assert os.path.isfile(p)
    return STUB_REPLY


class TestVision(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="manga-vision-test-")
        mv.VISION_CALL = _stub

    def test_pick_spreads_bounded_and_ordered(self):
        names = sorted("p%03d.png" % i for i in range(20))
        pairs = mv.pick_spreads(names, count=4)
        self.assertEqual(len(pairs), 4)
        for a, b in pairs:
            self.assertEqual(names.index(b), names.index(a) + 1)

    def test_distill_lesson_shape(self):
        spreads = [json.loads(STUB_REPLY),
                   dict(json.loads(STUB_REPLY), narrative_mode="mixed")]
        lessons = mv.distill(spreads)
        self.assertEqual(lessons["ratios"]["image_only"], 0.5)
        self.assertEqual(lessons["ratios"]["mixed"], 0.5)
        self.assertTrue(all("narrative_mode" in b for b in lessons["beats"]))
        self.assertIn("narrative-mode", lessons["script_annotation"])

    def test_run_end_to_end_stub(self):
        cbz = _fixture_cbz(self.tmp)
        lessons = mv.run(cbz, "Fixture")
        self.assertEqual(lessons["title"], "Fixture")
        self.assertEqual(lessons["spreads_sampled"], 4)
        self.assertTrue(lessons["ratios"]["image_only"] > 0)

    def test_cli_line_is_json(self):
        cbz = _fixture_cbz(self.tmp)
        out = os.path.join(self.tmp, "lessons.json")
        subprocess.run(
            ["python3", str(ROOT / "jobs" / "manga-vision.py"),
             "--archive", cbz, "--title", "Fixture", "--out", out],
            check=True, env={**os.environ, "MANGA_VISION_TEST_STUB": "1"})
        lessons = json.load(open(out))
        self.assertIn("ratios", lessons)


if __name__ == "__main__":
    unittest.main()
