#!/usr/bin/env python3
"""manga-draft P0 slice, hermetic: style-row parse, plan determinism,
lane-line parsing, SVG placeholder fill, garbage rejection."""
import importlib.util
import json
import os
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


md = _load("manga_draft", "jobs/manga-draft.py")

ITEM_TEXT = ("NOTABLE: Diplomatic Cooperation Bank Announces Peace Fund "
             "(https://example.com/news/1)")
FIXTURE_TSV = "\n".join([
    "manga-panel\t4:3\t1024x768\t771\t{SUBJECT}, gag panel\ttext\t",
    "",
])


class TestParse(unittest.TestCase):
    def test_lane_line_parses(self):
        item = md.parse_item(ITEM_TEXT)
        self.assertEqual(item["band"], "NOTABLE")
        self.assertEqual(item["url"], "https://example.com/news/1")
        self.assertIn("Peace Fund", item["headline"])

    def test_garbage_refused(self):
        self.assertIsNone(md.parse_item("not a lane line"))
        self.assertIsNone(md.parse_item("NOTABLE: no url here"))

    def test_style_row_parse(self):
        with tempfile.NamedTemporaryFile("w", suffix=".tsv",
                                         delete=False) as fh:
            fh.write(FIXTURE_TSV)
            path = fh.name
        try:
            style, prompt = md.image_prompt(path, "test subject")
            self.assertEqual(style, "manga-panel")
            self.assertTrue(prompt.startswith("test subject, gag panel"))
        finally:
            os.unlink(path)


class TestPlan(unittest.TestCase):
    def test_plan_deterministic_and_labeled(self):
        item = md.parse_item(ITEM_TEXT)
        p1 = md.plan_for(item)
        p2 = md.plan_for(item)
        self.assertEqual(p1, p2)
        self.assertIn("DRAMATIZATION", p1["attribution"])
        self.assertIn(item["url"], p1["attribution"])
        self.assertIn(item["headline"], p1["narrative"])
        self.assertTrue(p1["sfx"].isalpha())

    def test_plan_cameo_and_quip_budget(self):
        item = md.parse_item(ITEM_TEXT)
        p = md.plan_for(item)
        self.assertIn(p["cameo"], md.CAMEOS)
        self.assertIn(p["scene"], md.SCENES[p["cameo"]])
        self.assertIn(p["dialogue"], md.REACTIONS[p["cameo"]])
        self.assertLessEqual(len(p["dialogue"]), md.QUIP_BUDGET)

    def test_plan_missing_style_row(self):
        with tempfile.NamedTemporaryFile("w", suffix=".tsv",
                                         delete=False) as fh:
            fh.write("")
            path = fh.name
        try:
            plan = md.plan_for(md.parse_item(ITEM_TEXT), styles_tsv=path)
            self.assertIsNone(plan["style_id"])
            self.assertIsNone(plan["image_prompt"])
        finally:
            os.unlink(path)


class TestRender(unittest.TestCase):
    def test_svg_filled_and_escaped(self):
        plan = md.plan_for(md.parse_item(ITEM_TEXT))
        plan["narrative"] = 'Grounded <script>alert(1)</script> event'
        svg = md.render_svg(plan, panel_svg=str(ROOT / "config/manga-panel.svg"))
        self.assertIsNotNone(svg)
        self.assertNotIn("{{", svg)
        self.assertNotIn("<script>", svg)
        self.assertIn("&lt;script&gt;", svg)
        self.assertIn("DRAMATIZATION", svg)

    def test_svg_missing_skeleton(self):
        plan = md.plan_for(md.parse_item(ITEM_TEXT))
        self.assertIsNone(md.render_svg(plan, panel_svg="/nonexistent.svg"))


if __name__ == "__main__":
    unittest.main()
