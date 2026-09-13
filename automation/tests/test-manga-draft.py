#!/usr/bin/env python3
"""manga-draft P0 slice, hermetic: style-row parse, plan determinism,
lane-line parsing, SVG placeholder fill, garbage rejection."""
import importlib.util
import json
import os
import re
import sys
import tempfile
import unittest
from xml.sax.saxutils import escape
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


class TestRegisters(unittest.TestCase):
    """Operator critique 2, item 4: dialogue comes from PER-BEAT-TYPE
    registers (setup = flat narration, reaction = recognition,
    gag = punch), not one generic pool."""

    def setUp(self):
        self.plan = md.plan_for(md.parse_item(ITEM_TEXT))

    def test_beats_carry_register_lines(self):
        script = md.script_for(self.plan)
        kinds = [(b["kind"], b["register"], b["line"])
                 for b in script["beats"]]
        self.assertEqual([k[0] for k in kinds],
                         ["setup", "reaction", "gag"])
        self.assertEqual([k[1] for k in kinds],
                         ["narration", "recognition", "punch"])

    def test_three_beats_three_distinct_lines_registers(self):
        script = md.script_for(self.plan)
        lines = [b["line"] for b in script["beats"]]
        self.assertEqual(len(set(lines)), 3)
        self.assertIn(lines[0], md.NARRATIONS)
        self.assertIn(lines[1], md.RECOGNITIONS[self.plan["cameo"]])
        self.assertIn(lines[2], md.REACTIONS[self.plan["cameo"]])

    def test_setup_line_matches_plan_narration(self):
        script = md.script_for(self.plan)
        self.assertEqual(script["beats"][0]["line"],
                         self.plan["narration"])

    def test_gag_line_matches_plan_dialogue(self):
        script = md.script_for(self.plan)
        self.assertEqual(script["beats"][2]["line"],
                         self.plan["dialogue"])


class TestStrip(unittest.TestCase):
    """Operator critique 2, items 2/3/5: the wireframe IS the beat
    visualization -- a 3-beat script renders a multi-panel strip with
    gutters; a 1-beat script keeps the single-panel fallback."""

    def setUp(self):
        self.plan = md.plan_for(md.parse_item(ITEM_TEXT))
        self.script = md.script_for(self.plan)

    def test_three_beats_make_horizontal_strip(self):
        grid = md.panel_grid(3)
        self.assertEqual(grid["orientation"], "horizontal")
        self.assertEqual(len(grid["panels"]), 3)
        rects = grid["panels"]
        # distinct frames, gutters (gaps) between, shared top edge
        self.assertEqual(len({r[0] for r in rects}), 3)
        self.assertEqual(len({r[1] for r in rects}), 1)
        for a, b in zip(rects, rects[1:]):
            self.assertGreaterEqual(b[0], a[0] + a[2])  # gutter gap

    def test_two_beats_make_vertical_strip(self):
        grid = md.panel_grid(2)
        self.assertEqual(grid["orientation"], "vertical")
        self.assertEqual(len(grid["panels"]), 2)
        (ax, ay, aw, ah), (bx, by, bw, bh) = grid["panels"]
        self.assertEqual(ax, bx)
        self.assertGreaterEqual(by, ay + ah)  # stacked with a gutter

    def test_wireframe_one_frame_per_beat(self):
        svg = md.wireframe_svg(self.plan, self.script)
        # density rule (2026-09-12 collection study): 3 story beats
        # plan 4 panels -- the content-heavy setup beat splits in two;
        # each beat still owns exactly one data-beat marker.
        self.assertEqual(svg.count("<g data-beat="), 3)
        self.assertEqual(svg.count("<g data-panel="), 4)
        self.assertEqual(svg.count("<g data-panelimg="), 4)

    def test_wireframe_single_beat_fallback(self):
        one = {"narration": self.script["narration"],
               "beats": self.script["beats"][:1],
               "cast_sheet": self.script["cast_sheet"]}
        svg = md.wireframe_svg(self.plan, one)
        self.assertEqual(svg.count("<g data-panel="), 1)

    def test_beat_lines_rendered_in_their_panels(self):
        """The script is visibly consumed: each beat's register line
        lands in its own panel."""
        svg = md.wireframe_svg(self.plan, self.script)
        for b in self.script["beats"]:
            self.assertIn(escape(b["line"][:20]), svg)


class TestBubbleTails(unittest.TestCase):
    """Operator critique 2, item 1: curved bezier tails anchored to the
    actor, ink-wash wobble, no bare polygon triangles."""

    def setUp(self):
        self.plan = md.plan_for(md.parse_item(ITEM_TEXT))
        self.script = md.script_for(self.plan)

    def test_no_polygon_tails(self):
        svg = md.wireframe_svg(self.plan, self.script)
        self.assertNotIn("<polygon", svg)

    def test_tails_are_two_segment_quadratics(self):
        svg = md.wireframe_svg(self.plan, self.script)
        self.assertTrue(re.search(
            r'<path class="tail" d="M\d+ \d+ Q[\d.]+ [\d.]+ [\d.]+ [\d.]+ '
            r'Q[\d.]+ [\d.]+ [\d.]+ [\d.]+"', svg))

    def test_tails_carry_ink_filter(self):
        svg = md.wireframe_svg(self.plan, self.script)
        self.assertRegex(svg, r'class="tail"[^>]*filter="url\(#ink\)"')


class TestSfxPlacement(unittest.TestCase):
    """Operator critique 2, item 2: SFX anchors where the beat's focal
    action is; the quadrant varies with the seed (3 seeds -> 3
    quadrants), not a fixed corner."""

    PANEL = (14, 14, 324, 640)

    def test_quadrant_variance_across_seeds(self):
        rect = self.PANEL
        focal = (rect[0] + rect[2] * 0.5, rect[1] + rect[3] * 0.4)
        quads = set()
        for seed in (0, 1, 2):
            x, y = md.sfx_anchor(rect, focal, seed)
            quads.add((x > rect[0] + rect[2] / 2, y > rect[1] + rect[3] / 2))
        self.assertEqual(len(quads), 3)

    def test_anchor_stays_inside_panel(self):
        rect = self.PANEL
        for seed in range(12):
            x, y = md.sfx_anchor(rect, (rect[0] + 162, rect[1] + 256), seed)
            self.assertTrue(rect[0] <= x <= rect[0] + rect[2])
            self.assertTrue(rect[1] <= y <= rect[1] + rect[3])

    def test_wireframe_sfx_lands_in_beat_panel(self):
        plan = md.plan_for(md.parse_item(ITEM_TEXT))
        script = md.script_for(plan)
        svg = md.wireframe_svg(plan, script)
        m = re.search(r'<text[^>]*data-sfx[^>]*x="([\d.]+)" y="([\d.]+)"',
                      svg)
        self.assertIsNotNone(m)
        x, y = float(m.group(1)), float(m.group(2))
        self.assertNotEqual((x, y), (90, 545))  # not the fixed legacy spot
        grid = md.panel_grid(len(md.beat_panels(script)))
        inside = [i for i, r in enumerate(grid["panels"])
                  if r[0] <= x <= r[0] + r[2] and r[1] <= y <= r[1] + r[3]]
        # panels: setup-wide(0) setup-close(1) reaction(2) gag(3)
        self.assertEqual(inside, [2])  # the reaction beat's panel


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


class TestDensity(unittest.TestCase):
    """Bank delta 1 (2026-09-12 collection study): the wireframe plans
    3-5 panels per page on story beats (masters ran 4.6 avg; our 1-3
    under-ran), 1 panel for splash beats."""

    def setUp(self):
        self.plan = md.plan_for(md.parse_item(ITEM_TEXT))
        self.script = md.script_for(self.plan)

    def test_story_beats_land_in_density_band(self):
        n = len(md.beat_panels(self.script))
        self.assertGreaterEqual(n, 3)
        self.assertLessEqual(n, 5)

    def test_content_heavy_beat_splits_across_panels(self):
        """The setup beat's visual note lists two eye-hits (caption,
        then the tilted structure) -> the wireframe splits it in two."""
        self.assertEqual(self.script["beats"][0]["panels"], 2)
        self.assertEqual(len(md.beat_panels(self.script)), 4)

    def test_splash_beat_stays_single_panel(self):
        script = dict(self.script)
        script["beats"] = [dict(b, splash=True)
                           for b in self.script["beats"]]
        self.assertEqual(len(md.beat_panels(script)), 3)

    def test_single_beat_script_stays_single_panel(self):
        one = {"narration": self.script["narration"],
               "beats": self.script["beats"][:1],
               "cast_sheet": self.script["cast_sheet"]}
        self.assertEqual(len(md.beat_panels(one)), 1)

    def test_panel_grid_supports_density(self):
        for n in (4, 5):
            grid = md.panel_grid(n)
            self.assertEqual(len(grid["panels"]), n)
            for x, y, w, h in grid["panels"]:
                self.assertGreaterEqual(x, 14)
                self.assertLessEqual(x + w, 1010)
                self.assertLessEqual(y + h, 664)  # above the band


class TestToneSequencing(unittest.TestCase):
    """Bank deltas 3+4 (2026-09-12 collection study): the wit is the
    tonal CONTRAST -- the grim setup beat plans mid-tone texture, the
    gag/reaction beats plan flat white; the adjacent tone delta is the
    timing. Tone targets ride the script, the wireframe (data-tone),
    and the component prompts."""

    def setUp(self):
        self.plan = md.plan_for(md.parse_item(ITEM_TEXT))
        self.script = md.script_for(self.plan)

    def test_beats_carry_tone_targets(self):
        for b in self.script["beats"]:
            self.assertIn("tone", b)
        self.assertEqual(self.script["beats"][0]["tone"], md.TONE_GRIM)
        self.assertEqual(self.script["beats"][1]["tone"], md.TONE_FLAT)
        self.assertEqual(self.script["beats"][2]["tone"], md.TONE_FLAT)

    def test_adjacent_tone_delta_setup_vs_gag(self):
        """The check the study proposes: the planned sequence
        alternates tone register between setup and gag panels."""
        tones = [b["tone"] for b in self.script["beats"]]
        self.assertNotEqual(tones[0], tones[2])

    def test_wireframe_annotates_tone_per_panel(self):
        svg = md.wireframe_svg(self.plan, self.script)
        self.assertEqual(svg.count("data-tone="), 4)
        self.assertIn('data-tone="%s"' % md.TONE_GRIM, svg)
        self.assertIn('data-tone="%s"' % md.TONE_FLAT, svg)

    def test_component_prompts_inherit_tone_targets(self):
        prompts = md.component_prompts(self.plan, self.script)
        by_region = {p["region"]: p for p in prompts}
        env = by_region["environment"]["prompt"]
        actor = by_region["actor:%s"
                          % self.script["beats"][0]["cast"][0]]["prompt"]
        self.assertIn("mid-gray", env)          # grim panel register
        self.assertIn("clean white ground", actor)  # gag flat-white


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


class TestBankExtensions(unittest.TestCase):
    """Policy clause (f) bank extensions (2026-09-12): every bank line
    is distinct, and the subtlety law holds everywhere the banks feed
    generated output -- no artist names in any bank text."""

    BANNED = ["tatsumi", "tezuka", "nihei", "hayashida", "matsumoto"]

    def test_bank_lines_distinct(self):
        self.assertEqual(len(set(md.NARRATIONS)), len(md.NARRATIONS))
        self.assertEqual(len(set(md.MARGIN_NOTES)), len(md.MARGIN_NOTES))
        for cameo in md.CAMEOS:
            pool = md.RECOGNITIONS[cameo]
            self.assertEqual(len(set(pool)), len(pool))

    def test_quips_bank_lines_distinct(self):
        quips = _load("quips_test", "lib/quips.py")
        for bank in quips.BANKS.values():
            self.assertEqual(len(set(bank)), len(bank))

    def test_no_artist_names_in_banks(self):
        pools = [md.NARRATIONS, md.MARGIN_NOTES]
        pools += [md.RECOGNITIONS[c] for c in md.CAMEOS]
        quips = _load("quips_test", "lib/quips.py")
        pools += [b for b in quips.BANKS.values()]
        for line in [ln for pool in pools for ln in pool]:
            low = line.lower()
            for name in self.BANNED:
                self.assertNotIn(name, low)

    def test_quip_banks_format_without_crash(self):
        """A new bank line must never crash the paper: every bank is
        renderable with the facts its renderer actually passes (none
        for comic/machine_hall; each bank's own placeholders are the
        renderer's contract)."""
        quips = _load("quips_test", "lib/quips.py")
        self.assertTrue(quips.quip("comic", "2026-09-12"))
        self.assertTrue(quips.quip("machine_hall", "2026-09-12"))
        self.assertTrue(quips.quip("ledger", "2026-09-12", spend=1.25,
                                   calls=10, quiet=2))
        self.assertTrue(quips.quip("patrol", "2026-09-12", surfaces=3,
                                   passes=2, fails=1))
        self.assertTrue(quips.quip("deck_b", "2026-09-12", tokens=99))


if __name__ == "__main__":
    unittest.main()
