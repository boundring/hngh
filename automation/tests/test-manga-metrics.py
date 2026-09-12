#!/usr/bin/env python3
"""manga-metrics + manga-manifest P0 slice, hermetic: synthetic-bitmap
panel detection, tone coverage, real-tree manifest counts. No network."""
import importlib.util
import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # automation/


def _load(name, rel):
    spec = importlib.util.spec_from_file_location(name, str(ROOT / rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


mm = _load("manga_metrics", "jobs/manga-metrics.py")
mf = _load("manga_manifest", "jobs/manga-manifest.py")

COLLECTION = os.path.expanduser("~/Documents/manga")


def _fixture_page(tmp, name, bands):
    """Synthetic manga page: `bands` black-bordered panels on white, plus
    a gray screentone block in the top band (tone-detection fixture)."""
    W, H = 600, 900
    bh = H // bands
    ops = ["-size", "%dx%d" % (W, H), "canvas:white"]
    for i in range(bands):
        y = i * bh + 10
        ops += ["-fill", "black", "-draw",
                "rectangle 20,%d 580,%d" % (y, y + bh - 20),
                "-fill", "white", "-draw",
                "rectangle 30,%d 570,%d" % (y + 10, y + bh - 30)]
        if i == 0:  # screentone-ish mid-gray fill inside the first panel
            ops += ["-fill", "rgb(150,150,150)", "-draw",
                    "rectangle 60,%d 300,%d" % (y + 30, y + bh - 60)]
    out = os.path.join(tmp, name)
    subprocess.run(["magick"] + ops + ["png:" + out], check=True,
                   capture_output=True)
    return out


class TestMetrics(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix="manga-metrics-test-")

    def test_two_band_page_detects_bands_and_tone(self):
        page = _fixture_page(self.tmp, "two.png", 2)
        m = mm.analyze(page)
        self.assertGreaterEqual(m["panel_bands"], 2)
        self.assertGreaterEqual(m["panels_est"], 2)
        self.assertGreater(m["ink_coverage"], 0.005)   # panel borders
        self.assertGreater(m["tone_coverage"], 0.02)   # gray block
        self.assertGreater(m["white_coverage"], 0.5)

    def test_four_band_page_outranks_two(self):
        two = mm.analyze(_fixture_page(self.tmp, "a.png", 2))
        four = mm.analyze(_fixture_page(self.tmp, "b.png", 4))
        self.assertGreaterEqual(four["panel_bands"], two["panel_bands"])

    def test_cli_line_is_json(self):
        page = _fixture_page(self.tmp, "c.png", 3)
        out = subprocess.run(
            ["python3", str(ROOT / "jobs" / "manga-metrics.py"),
             "--title", "Fixture", page],
            capture_output=True, text=True, check=True)
        row = json.loads(out.stdout.strip())
        self.assertEqual(row["title"], "Fixture")
        self.assertIn("panels_est", row)


class TestManifest(unittest.TestCase):
    @unittest.skipUnless(os.path.isdir(COLLECTION),
                         "collection not mounted")
    def test_real_tree_counts(self):
        data = mf.scan(COLLECTION, sample=1)
        names = [t["title"] for t in data["titles"]]
        self.assertTrue(names)
        tez = next(t for t in data["titles"] if "Tezuka" in t["title"])
        self.assertGreater(sum(tez["archives"].values()), 100)
        flagged = {t["title"]: t["style_reference"] for t in data["titles"]}
        flat = [r for v in flagged.values() for r in v]
        for artist in ("tezuka", "nihei", "matsumoto", "hayashida"):
            self.assertIn(artist, flat)
        # page samples counted images, never extracted files
        for t in data["titles"]:
            for s in t["page_count_sample"]:
                self.assertGreater(s["image_members"], 0)


if __name__ == "__main__":
    unittest.main()