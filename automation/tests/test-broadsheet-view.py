#!/usr/bin/env python3
"""Broadsheet front page contract (standalone v1, 2026-09-27).

dashboard/broadsheet.html is the WebGL broadsheet (broadsheet-view.js +
broadsheet.css), staged standalone BEFORE the index.html cutover:

- paper texture: raw WebGL2 fragment shader behind the DOM, with a
  plain-CSS fail-open paper when WebGL2 is unavailable;
- megastructure map: vendored three.js (r160) node graph with live
  fleet.json nodes, 2D fallback on any failure;
- CSS multicol stream over newspaper.json (columns in localStorage),
  operator choice cards POSTing the token-gated endpoints with
  X-Hngh-Token, infinite loop through stored editions behind a
  FRESH EDITION divider;
- poll hygiene: refresh only via the poll chain or the refresh button
  (raw timer loops are banned, same contract as the newspaper);
- fail-closed rendering: an unreachable feed shows banner #papererr,
  never a blank page;
- offline: three.js and the four Averia Libre woff2 faces are vendored
  locally; no CDN link ships in the page.

Hermetic static analysis only -- no network, no browser.
"""

import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DASH = ROOT / "dashboard"


def read(name):
    return (DASH / name).read_text(encoding="utf-8")


class VendoredAssets(unittest.TestCase):
    """The page must run fully offline: vendor + 4 fonts, non-trivial."""

    def test_three_vendored(self):
        p = DASH / "vendor" / "three.module.min.js"
        self.assertTrue(p.is_file(), "vendor/three.module.min.js missing")
        self.assertGreater(p.stat().st_size, 300_000, "three.js too small")

    def test_fonts_vendored(self):
        for face in ("Regular", "Bold", "Italic", "BoldItalic"):
            p = DASH / "fonts" / f"AveriaLibre-{face}.woff2"
            self.assertTrue(p.is_file(), f"{p.name} missing")
            self.assertGreater(p.stat().st_size, 10_000, f"{p.name} too small")


class Mount(unittest.TestCase):
    def setUp(self):
        self.html = read("broadsheet.html")

    def test_mounts_view_and_styles(self):
        self.assertIn("broadsheet-view.js", self.html)
        self.assertIn("broadsheet.css", self.html)

    def test_error_banner_mounted(self):
        self.assertIn('id="papererr"', self.html)

    def test_no_cdn_links(self):
        self.assertNotIn("cdn.jsdelivr.net", self.html)
        self.assertNotIn("unpkg.com", self.html)
        self.assertNotIn("fonts.googleapis.com", self.html)


class BroadsheetViewJs(unittest.TestCase):
    """The JS contracts the page cannot work without."""

    def setUp(self):
        self.js = read("broadsheet-view.js")

    def test_no_setInterval(self):
        self.assertNotIn("setInterval(", self.js)

    def test_bounded_fetches(self):
        self.assertIn("AbortController", self.js)
        self.assertIn("cache: 'no-store'", self.js)

    def test_token_and_endpoints(self):
        self.assertIn('meta[name="hngh-token"]', self.js)
        self.assertIn('"/operator-item/handle"', self.js)
        self.assertIn('"/operator-item/dismiss"', self.js)
        self.assertIn("X-Hngh-Token", self.js)

    def test_fail_closed_banner(self):
        self.assertIn('"papererr"', self.js)

    def test_webgl2_fallback_branch(self):
        self.assertIn("getContext('webgl2'", self.js)
        self.assertIn("paper-fallback", self.js)
        self.assertIn("webglcontextlost", self.js)

    def test_column_config_in_localStorage(self):
        self.assertIn("localStorage", self.js)
        self.assertIn("'broadsheet-cols'", self.js)

    def test_fresh_edition_loop(self):
        self.assertIn("FRESH EDITION", self.js)
        self.assertIn("IntersectionObserver", self.js)

    def test_feed_stamp_not_client_date(self):
        self.assertIn("todayFromStamp", self.js)
        self.assertIn("esc(", self.js)

    def test_outcome_visible_before_click(self):
        self.assertIn("className = 'outcome'", self.js)

    def test_flood_family_collapse(self):
        self.assertIn("'[feedback:idea] from email'", self.js)
        self.assertIn("floodIds", self.js)
        self.assertIn("The empty-idea flood (' + n + ' items)", self.js)
        self.assertIn("Dismiss all ' + nLabel", self.js)
        self.assertIn("'/operator-item/dismiss'", self.js)
        self.assertIn("FLOOD_MAX_DISMISS = 80", self.js)


class Styles(unittest.TestCase):
    def setUp(self):
        self.css = read("broadsheet.css")

    def test_averia_faces_vendored_with_swap(self):
        self.assertEqual(self.css.count("@font-face"), 4)
        self.assertIn("AveriaLibre-Regular.woff2", self.css)
        self.assertIn("font-display: swap", self.css)

    def test_paper_canvas_and_multicol(self):
        self.assertIn("#paper-canvas", self.css)
        self.assertIn("column-count", self.css)
        self.assertIn("column-span: all", self.css)


class SampleFixture(unittest.TestCase):
    """Dev fixture: exact top-level keys of the composer contract."""

    def test_parses_with_contract_keys(self):
        data = json.loads(read("broadsheet.sample.json"))
        self.assertEqual(
            sorted(data.keys()),
            ["articles", "edition", "editions", "generated", "queues"])
        self.assertTrue(data["articles"])
        for a in data["articles"]:
            for key in ("id", "category", "headline", "body",
                        "span", "score", "ts", "choices"):
                self.assertIn(key, a)
        self.assertIn(data["edition"]["slot"], (0, 1, 2))


if __name__ == "__main__":
    unittest.main()
