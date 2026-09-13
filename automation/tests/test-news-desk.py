#!/usr/bin/env python3
"""The news-desk lane, hermetic: headline post-processing (polish +
fail-closed passthrough), the category mapping table, writer-profile
rotation, the [Cat] digest marker round-trip through Deck A, and the
~/.hngh dispatch writer. No network beyond refused localhost ports."""
import importlib.util
import os
import unittest.mock
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


gn = _load("gdelt_news", "jobs/gdelt-news.py")
dh = _load("digest_html", "jobs/digest-html.py")
na = _load("news_articles", "jobs/news-articles.py")

ITEM = {"root": "19", "quad": "4", "lane": "world",
        "actors": "RUSSIA/UKRAINE", "url": "https://x.test/a"}


class HeadlinePostProcessor(unittest.TestCase):
    def test_polish_is_procedural_no_model_calls(self):
        # paid-cost conversion 2026-09-13: the slug headline passes
        # through normalization only -- never a model call.
        self.assertEqual(gn.polish_headline(ITEM, "73703865"), "73703865")
        self.assertEqual(gn.polish_headline(ITEM, "Raw Slug"), "Raw Slug")

    def test_polish_normalizes_deterministically(self):
        self.assertEqual(gn.polish_headline(
            ITEM, '  "BREAKING:   Two  Divisions Engaged"  '),
            "Two Divisions Engaged")
        self.assertEqual(gn.polish_headline(
            ITEM, "Report - Fixture War Escalates"), "Fixture War Escalates")


class CategoryMapping(unittest.TestCase):
    def test_root_beats_quad(self):
        self.assertEqual(gn.category_of(
            {"root": "19", "quad": "4"}), "Conflict")
        self.assertEqual(gn.category_of(
            {"root": "05", "quad": "1"}), "World News")
        self.assertEqual(gn.category_of(
            {"root": "06", "quad": "2"}), "Economics")
        self.assertEqual(gn.category_of(
            {"root": "14", "quad": "3"}), "Politics")

    def test_quad_fallback_and_default(self):
        self.assertEqual(gn.category_of({"root": "", "quad": "2"}),
                         "Economics")
        self.assertEqual(gn.category_of({"root": "zz", "quad": ""}),
                         "World News")

    def test_gkg_theme_overlap_beats_cameo(self):
        self.assertEqual(gn.category_of(
            {"root": "05", "quad": "1", "themes": ["ECON_ECONOMICSPOLICY"]}),
            "Economics")
        self.assertEqual(gn.category_of(
            {"root": "05", "quad": "1", "themes": ["TECH_AI"]}),
            "Technology")
        self.assertEqual(gn.category_of(
            {"root": "19", "quad": "4", "themes": ["CULTURE_ARTS"]}),
            "Culture")


class WriterProfileRotation(unittest.TestCase):
    def setUp(self):
        self.profiles = na.load_profiles(str(ROOT / "config"
                                           / "writer-profiles.tsv"))

    def test_cast_loaded_from_tsv(self):
        names = [p["name"] for p in self.profiles]
        self.assertGreaterEqual(len(names), 4)
        self.assertIn("The Night Ledger", names)
        self.assertIn("Sector 7 Sentinel", names)

    def test_deterministic_and_rotates_by_day(self):
        a = na.pick_profile("2026-09-13", "fixture-story", self.profiles)
        b = na.pick_profile("2026-09-14", "fixture-story", self.profiles)
        self.assertEqual(a, na.pick_profile("2026-09-13", "fixture-story",
                                            self.profiles))
        self.assertNotEqual(a["name"], b["name"])

    def test_empty_cast_fail_open(self):
        self.assertIsNone(na.pick_profile("2026-09-13", "x", []))

    def test_prompt_carries_profile_voice_law(self):
        item = {"title": "T", "tag": "NOTABLE", "place": "", "url": "u"}
        p = self.profiles[0]
        out = na.build_prompt(item, None, "", p)
        self.assertIn(p["name"], out)
        self.assertIn("voice, never facts", out)


class CategoryMarkerRoundTrip(unittest.TestCase):
    FIXTURE = """## 0400 2026-09-13
_sources: gdelt | model: gdelt-2.0 export_
CRITICAL: [Conflict] FIGHT RUSSIA/UKRAINE: Eight killed in strikes (https://x.test/a)
NOTABLE: [World News] DIPLOMATIC-COOPERATION SWEDEN/GERMANY: Swedes vote (https://x.test/b)
NOTABLE: [Economics] MATERIAL-COOPERATION OPEC: Output steady (https://x.test/c)
NOTABLE: [Conflict] FIGHT SUDAN/DARFUR: Convoy attacked (https://x.test/d)
"""

    def _sections(self):
        return dh.parse_sections(self.FIXTURE)

    def test_deck_a_groups_under_category_headers(self):
        page = dh.render_deck_a(self._sections(), 1, {})
        for cat in ("Conflict", "World News", "Economics"):
            self.assertIn('<p class="cathead">%s</p>' % cat, page)
        self.assertNotIn("[Conflict]", page)

    def test_collect_items_strips_marker_and_records_category(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "2026-09-13.md")
            with open(p, "w") as f:
                f.write(self.FIXTURE)
            items = na.collect_items(p)
        heads = {i["head"] for i in items}
        self.assertEqual(items[0]["category"], "Conflict")
        self.assertIn(
            "FIGHT RUSSIA/UKRAINE: Eight killed in strikes "
            "(https://x.test/a)", heads)


class DispatchWriter(unittest.TestCase):
    DATE = "2026-09-13"

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        d = os.path.join(self.tmp.name, "digest")
        os.makedirs(d)
        with open(os.path.join(d, self.DATE + ".md"), "w") as f:
            f.write(CategoryMarkerRoundTrip.FIXTURE)
        env = {"HNGH_HOME_DIR": self.tmp.name,
               "HNGH_DIGESTS_DIR": d,
               "HNGH_TELEMETRY_DB": os.path.join(self.tmp.name, "no.db")}
        for k, v in env.items():
            os.environ[k] = v

    def _publish(self):
        dl = _load("digest_local", "jobs/digest-local.py")
        self.assertEqual(dl.main([self.DATE]), 0)
        home = self.tmp.name
        return (os.path.join(home, "dispatch", self.DATE, "index.html"),
                os.path.join(home, "dispatch", "index.html"))

    def test_publish_writes_self_contained_edition(self):
        edition, index = self._publish()
        html = open(edition).read()
        self.assertIn("cathead", html)
        self.assertNotIn("/hngh-docs/media/", html)
        self.assertIn('href="2026-09-13/index.html"', open(index).read())


if __name__ == "__main__":
    sys.exit(0 if unittest.main(exit=False).result.wasSuccessful() else 1)