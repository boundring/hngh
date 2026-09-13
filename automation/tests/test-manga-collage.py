#!/usr/bin/env python3
"""manga-collage tests (policy clauses c/d): transformation is
non-verbatim, output is valid PNG, provenance cites the study never a
filename. Hermetic: no collection, no network -- a fixture zip stands
in for the archive; committed sample artifacts are checked as-is."""
import importlib.util
import json
import shutil
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # automation/
REPO = ROOT.parent


def _load(name, rel):
    spec = importlib.util.spec_from_file_location(name, str(ROOT / rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


mc = _load("manga_collage", "jobs/manga-collage.py")
COLLAGE_DIR = REPO / "docs" / "media" / "collage"
HAS_TOOLS = bool(shutil.which("magick")) and bool(shutil.which("rsvg-convert"))


class TestGeometry(unittest.TestCase):
    """Crop geometry: deterministic, three character bands + one
    environment frame, all inside the page."""

    def test_crop_rects_cover_register_layout(self):
        rects = mc.crop_rects(1000, 1600)
        self.assertEqual(len(rects), 4)
        kinds = [r[4] for r in rects]
        self.assertEqual(kinds.count("character"), 3)
        self.assertEqual(kinds[-1], "environment")
        for x, y, w, h, _ in rects:
            self.assertTrue(0 <= x and 0 <= y and x + w <= 1000
                            and y + h <= 1600)
        self.assertEqual(rects, mc.crop_rects(1000, 1600))


class TestOverlay(unittest.TestCase):
    """SVG overlay: screentone + frame, register law (no text)."""

    def test_overlay_has_tone_and_no_text(self):
        svg = mc.overlay_svg(480, 320, 7)
        self.assertIn("pattern", svg)
        self.assertIn("<circle", svg)
        self.assertNotIn("<text", svg)
        self.assertNotIn("font", svg.lower())


@unittest.skipUnless(HAS_TOOLS, "magick/rsvg-convert unavailable")
class TestTransform(unittest.TestCase):
    """The transformation: output valid PNG, never byte-equal to the
    source (policy clause c: transformed, not verbatim)."""

    def test_transform_output_valid_and_nonverbatim(self):
        with tempfile.TemporaryDirectory() as tmp:
            src = str(Path(tmp) / "p.png")
            subprocess.run(["magick", "-size", "200x300",
                            "gradient:white-black", "png:" + src],
                           check=True)
            out = str(Path(tmp) / "t.png")
            with open(src, "rb") as fh:
                src_bytes = fh.read()
            tw, th = mc.transform(src, out, mc.crop_rects(200, 300)[0], 7,
                                  target_w=300)
            with open(out, "rb") as fh:
                out_bytes = fh.read()
            self.assertEqual(out_bytes[:8], b"\x89PNG\r\n\x1a\n")
            self.assertNotEqual(out_bytes, src_bytes)
            self.assertEqual((tw, th), (300, 300))  # 100x100 crop @300w


@unittest.skipUnless(HAS_TOOLS, "magick/rsvg-convert unavailable")
class TestPipeline(unittest.TestCase):
    """End-to-end over a fixture zip (stands in for an archive)."""

    def test_main_runs_on_fixture_and_hides_provenance(self):
        with tempfile.TemporaryDirectory() as tmp:
            page = str(Path(tmp) / "page.png")
            subprocess.run(["magick", "-size", "400x600",
                            "gradient:white-black", "png:" + page],
                           check=True)
            root = Path(tmp) / "col"
            (root / "fixture").mkdir(parents=True)
            arc = root / "fixture" / "fixture.zip"
            with zipfile.ZipFile(arc, "w") as zf:
                for i in range(2):
                    zf.write(page, "pages/page-%03d.png" % i)
            manifest = Path(tmp) / "m.json"
            manifest.write_text(json.dumps({
                "root": str(root),
                "titles": [{"title": "fixture",
                            "style_reference": ["x"],
                            "page_count_sample":
                                [{"archive": "fixture.zip",
                                  "image_members": 2}]}]}))
            out = Path(tmp) / "out"
            rc = mc.main(["--manifest", str(manifest), "--out", str(out),
                          "--seed", "1", "--slug", "t"])
            self.assertEqual(rc, 0)
            png = Path(out) / "collage-t.png"
            self.assertEqual(png.read_bytes()[:8], b"\x89PNG\r\n\x1a\n")
            meta = json.loads((Path(out) / "collage-t.json").read_text())
            self.assertNotIn(str(tmp), json.dumps(meta))
            self.assertNotIn(".zip", json.dumps(meta))


class TestCommittedSample(unittest.TestCase):
    """The committed derivative: valid PNG, provenance cites the study
    and the policy, no source filename or path leaks (clause d)."""

    def setUp(self):
        self.png = COLLAGE_DIR / "collage-sample.png"
        self.meta = COLLAGE_DIR / "collage-sample.json"

    def test_sample_exists_and_is_png(self):
        self.assertTrue(self.png.is_file(), self.png)
        self.assertTrue(self.meta.is_file(), self.meta)
        self.assertEqual(self.png.read_bytes()[:8], b"\x89PNG\r\n\x1a\n")

    def test_provenance_cites_study_not_filename(self):
        text = self.meta.read_text()
        self.assertIn("collection study", text)
        self.assertIn("manga-collection-policy", text)
        for leak in (".cbz", ".rar", ".zip", "~/Documents",
                     "/home/bricker/Documents"):
            self.assertNotIn(leak, text)
        self.assertIn("recolor", text)  # transformed, not verbatim


if __name__ == "__main__":
    unittest.main(verbosity=2)