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
        # hyphenated onomatopoeia (TAK-TAK-TAK) is legal; banks are cameo-keyed
        self.assertRegex(p1["sfx"], r"^[A-Z]+(-[A-Z]+)*$")
        self.assertIn(p1["sfx"], md.SFX_BANK[p1["cameo"]])
        self.assertTrue(p1["margin"])

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
        self.assertIn('transform="rotate(', svg)  # SFX placement + tilt jitter
        self.assertIn(plan["margin"], svg)
        self.assertNotIn("<script>", svg)
        self.assertIn("&lt;script&gt;", svg)
        self.assertIn("DRAMATIZATION", svg)

    def test_svg_missing_skeleton(self):
        plan = md.plan_for(md.parse_item(ITEM_TEXT))
        self.assertIsNone(md.render_svg(plan, panel_svg="/nonexistent.svg"))


class TestScript(unittest.TestCase):
    """Pass 1: the script layer -- beats with visual notes."""

    def setUp(self):
        self.plan = md.plan_for(md.parse_item(ITEM_TEXT))

    def test_script_beats_exist(self):
        script = md.script_for(self.plan)
        self.assertTrue(script["beats"])
        kinds = [b["kind"] for b in script["beats"]]
        for kind in ("setup", "reaction", "gag"):
            self.assertIn(kind, kinds)

    def test_beats_carry_visual_notes(self):
        script = md.script_for(self.plan)
        for b in script["beats"]:
            self.assertIn("visual", b)
            self.assertIn("cast", b)
            self.assertIn(b["cast"][0], md.CAMEOS)

    def test_beat_types_cover_pose_library(self):
        script = md.script_for(self.plan)
        poses = {b["pose"] for b in script["beats"]}
        self.assertTrue(poses <= set(md.POSE_LIBRARY))

    def test_script_deterministic(self):
        self.assertEqual(md.script_for(self.plan), md.script_for(self.plan))

    def test_narration_register_in_plan_and_script(self):
        """The serious-manga deadpan narration rides the plan and the
        setup beat (operator steer: flat declarative narration of the
        machine's small dramas, played straight)."""
        self.assertIn(self.plan["narration"], md.NARRATIONS)
        script = md.script_for(self.plan)
        self.assertEqual(script["narration"], self.plan["narration"])
        self.assertIn(script["beats"][0]["kind"], "setup")
        self.assertIn(self.plan["narration"],
                      script["beats"][0]["visual"])


class TestWireframe(unittest.TestCase):
    """Pass 2: procedural SVG wireframe from the script."""

    def setUp(self):
        self.plan = md.plan_for(md.parse_item(ITEM_TEXT))
        self.script = md.script_for(self.plan)

    def test_wireframe_valid_svg_shape(self):
        svg = md.wireframe_svg(self.plan, self.script)
        self.assertIn("<svg", svg)
        self.assertIn("</svg>", svg)
        self.assertIn("stroke-width", svg)

    def test_wireframe_carries_pose_and_focal(self):
        svg = md.wireframe_svg(self.plan, self.script)
        self.assertIn('data-pose="', svg)
        self.assertIn('data-focal="', svg)

    def test_wireframe_covers_every_beat(self):
        svg = md.wireframe_svg(self.plan, self.script)
        self.assertEqual(svg.count("data-beat"), len(self.script["beats"]))


class TestStyleCore(unittest.TestCase):
    """The style core: one string all component prompts inherit."""

    def test_style_core_is_single_string(self):
        self.assertIsInstance(md.STYLE_CORE, str)
        self.assertTrue(md.STYLE_CORE)

    def test_no_artist_names(self):
        banned = ["tatsumi", "tezuka", "nihei", "hayashida"]
        core = md.STYLE_CORE.lower()
        for name in banned:
            self.assertNotIn(name, core)

    def test_component_prompts_inherit_core(self):
        self.plan = md.plan_for(md.parse_item(ITEM_TEXT))
        self.script = md.script_for(self.plan)
        prompts = md.component_prompts(self.plan, self.script)
        self.assertTrue(prompts)
        for p in prompts:
            self.assertIn(md.STYLE_CORE, p["prompt"])
            low = p["prompt"].lower()
            for name in ("tatsumi", "tezuka", "nihei", "hayashida"):
                self.assertNotIn(name, low)

    def test_component_budget_enforced(self):
        self.plan = md.plan_for(md.parse_item(ITEM_TEXT))
        self.script = md.script_for(self.plan)
        prompts = md.component_prompts(self.plan, self.script)
        self.assertLessEqual(len(prompts), md.COMPONENT_BUDGET)

    def test_component_bounds_small(self):
        self.plan = md.plan_for(md.parse_item(ITEM_TEXT))
        self.script = md.script_for(self.plan)
        for p in md.component_prompts(self.plan, self.script):
            w, h = p["size"].split("x")
            self.assertLessEqual(int(w), 768)
            self.assertLessEqual(int(h), 768)


class TestCast(unittest.TestCase):
    """Character sheets: persisted appearance descriptor + seed."""

    def test_cast_file_loads(self):
        cast = md.load_cast(os.path.join(ROOT, "config", "manga-cast.json"))
        for cameo in md.CAMEOS:
            self.assertIn(cameo, cast)
            self.assertIn("appearance", cast[cameo])
            self.assertIn("seed", cast[cameo])


class TestAssemble(unittest.TestCase):
    """Pass 4: components composite into the panel skeleton."""

    def setUp(self):
        self.plan = md.plan_for(md.parse_item(ITEM_TEXT))
        self.script = md.script_for(self.plan)

    def test_components_layered_into_panel(self):
        svg = md.assemble_svg(self.plan, self.script, "wf", components={
            "environment": "env.png", "actor:engineer": "act.png"})
        self.assertIn('href="env.png"', svg)
        self.assertIn('href="act.png"', svg)

    def test_no_components_keeps_skeleton_fallback(self):
        svg = md.assemble_svg(self.plan, self.script, "wf", components={})
        self.assertIn("<svg", svg)
        self.assertNotIn("__COMPONENT_LAYERS__", svg)

    def test_text_layers_survive_assembly(self):
        svg = md.assemble_svg(self.plan, self.script, "wf", components={})
        self.assertIn("<ellipse", svg)       # speech bubble
        self.assertIn("DRAMATIZATION", svg)  # attribution footer


if __name__ == "__main__":
    unittest.main()
