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
import re
import subprocess
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


class FloodDismissImmediate(unittest.TestCase):
    """Dismissals reflect in the stream immediately (2026-09-27 fix).

    The feed is a ~30-minute composer snapshot; POSTing dismiss moves
    the id server-side only. The card's progress used to be wiped by a
    full stream rebuild from that same stale snapshot (the reported
    flash), and the rows never left the page until the next composer
    run. Contract: dismissed = gone, client-side, per id, live.
    """

    def setUp(self):
        self.js = read("broadsheet-view.js")

    def test_dismissed_ids_leave_stream_data(self):
        self.assertIn("localStorage", self.js)
        self.assertIn("'broadsheet-dismissed'", self.js)
        self.assertIn("dismissPersist(id)", self.js)
        self.assertIn("feed.dismissed[id] = true", self.js)
        # the refetch filter: the 30-min snapshot must not resurrect
        # rows this page already dismissed
        self.assertIn("!feed.dismissed[x.id]", self.js)

    def test_progress_stays_visible_no_rebuild_flash(self):
        self.assertIn("bar.appendChild(progress)", self.js)
        self.assertIn("'dismissed ' + done + ' of '", self.js)
        start = self.js.index("function floodChoicesEl")
        end = self.js.index("  // Operator decisions", start)
        self.assertNotIn(
            "rebuildStream(", self.js[start:end],
            "flood dismiss must not rebuild from the stale snapshot")

    def test_family_card_clears_itself(self):
        self.assertIn("flood-cleared", self.js)
        self.assertIn("replaceChild(note, card)", self.js)
        self.assertIn(".flood-cleared", read("broadsheet.css"))

    def test_single_failure_never_fails_batch(self):
        self.assertIn("failed.push(id)", self.js)
        self.assertIn("continuing", self.js)
        self.assertIn("failed ids: ' + failed.join(', ')", self.js)

    def test_progress_is_perceptible(self):
        # review F1: a 40-step chain at ~12ms/step reads as the old
        # flash; every step must stay on screen long enough to tick
        self.assertIn("FLOOD_STEP_MS", self.js)
        self.assertIn("Date.now() - t0", self.js)

    def test_completion_holds_before_reflow(self):
        # the final count must be readable before the tall card swaps
        self.assertIn("' - flood cleared.'", self.js)
        self.assertIn("}, 1500);", self.js)


class SplashMasthead(unittest.TestCase):
    """Volumetric ASCII splash + rotating H.N.G.H. expansions."""

    def setUp(self):
        self.js = read("broadsheet-view.js")

    def test_bitmap_font_renderer_present(self):
        self.assertIn("var GLYPHS = {", self.js)
        for row in ("'10001'", "'11111'", "'01110'"):
            self.assertIn(row, self.js)
        self.assertIn("function splashText(text, seed)", self.js)
        self.assertIn("function splashRender(ed, generated)", self.js)
        self.assertIn("SPLASH_RAMP", self.js)
        self.assertIn("'╔' + '═'.repeat(w) + '╗'", self.js)

    def test_splash_mounted_in_both_pages(self):
        for name in ("broadsheet.html", "index.html"):
            html = read(name)
            self.assertIn('id="mast-splash"', html)
            self.assertIn('id="mast-expansion"', html)
            self.assertIn('id="mast-sysline"', html)

    def test_expansion_list_spirit(self):
        m = re.search(r"var HN_GH = \[(.*?)\n  \];", self.js, re.S)
        self.assertTrue(m, "HN_GH array missing")
        entries = json.loads("[" + m.group(1) + "]")
        self.assertGreaterEqual(len(entries), 20)
        for e in entries:
            words = re.sub(r"[&,.]", " ", e).split()
            self.assertTrue(words, e)
            self.assertEqual(words[0][0], "H", e)
            rest = words[1:]
            self.assertTrue(any(w[0] == "N" for w in rest), e)
            self.assertTrue(any(w[0] == "G" for w in rest), e)
            self.assertTrue(any(w[0] == "H" for w in rest), e)

    def test_pick_deterministic_off_feed_stamp(self):
        self.assertIn("HN_GH[h32(stamp + '#' + num) % HN_GH.length]", self.js)
        self.assertNotIn("new Date", self.js)

    def test_sysline_feed_only(self):
        self.assertIn("[sys.hostname, sys.uptime]", self.js)
        self.assertIn(".mast-sysline:empty", read("broadsheet.css"))


class WeatherUnits(unittest.TestCase):
    """Celsius -> Fahrenheit: exact formula, both units, graceful hide."""

    def setUp(self):
        self.js = read("broadsheet-view.js")

    def test_exact_formula(self):
        self.assertIn("(c * 9 / 5 + 32).toFixed(1)", self.js)
        self.assertIn("'°C / '", self.js)

    def test_runtime_conversion_exact(self):
        m = re.search(r"function cToF\(c\) \{[\s\S]*?\n  \}", self.js)
        self.assertTrue(m, "cToF missing")
        out = subprocess.run(
            ["node", "-e", m.group(0) + ";"
             "console.log([cToF(14.3), cToF(-40), cToF(0)].join(' '))"],
            capture_output=True, text=True, check=True).stdout.split()
        self.assertEqual(out[0], "57.7")   # 14.3C is 57.7F (not 55.7F)
        self.assertEqual(out[1], "-40.0")  # the scales cross at -40
        self.assertEqual(out[2], "32.0")

    def test_missing_weather_hides(self):
        self.assertIn("report incomplete", self.js)   # temp missing, summary kept
        self.assertIn("'no weather report'", self.js)  # no weather at all


class FullPagePaper(unittest.TestCase):
    """Full-page paper sheet + reduced-motion dapple freeze + emboss."""

    def setUp(self):
        self.js = read("broadsheet-view.js")
        self.css = read("broadsheet.css")

    def test_reduced_motion_freezes_dapple(self):
        self.assertIn("prefers-reduced-motion", self.js)
        self.assertIn("paper.still ? 0 : (ts % 1e7) / 1000", self.js)
        self.assertIn("paper.still = rmq.matches", self.js)

    def test_emboss_on_frames_and_banners(self):
        self.assertIn("text-shadow", self.css)
        self.assertIn(".art .kicker { box-shadow:", self.css)
        self.assertIn(".masthead h1, .fresh-edition h2", self.css)


class GhostDesk(unittest.TestCase):
    """Ghost counsel renders inside expanded articles, silent when absent."""

    def setUp(self):
        self.js = read("broadsheet-view.js")

    def test_wiring_and_style(self):
        self.assertIn("ghostHTML(a.ghost)", self.js)
        css = read("broadsheet.css")
        self.assertIn(".ghostdesk", css)
        self.assertIn(".art.expanded .ghostdesk", css)

    def test_renders_when_present_silent_when_absent(self):
        esc = re.search(r"function esc\(s\) \{[\s\S]*?\n  \}", self.js)
        g = re.search(r"function ghostHTML\(g\) \{[\s\S]*?\n  \}", self.js)
        self.assertTrue(esc and g, "esc/ghostHTML missing")
        # inline fixture (never the real newspaper.json): ghost on/off
        script = (esc.group(0) + "\n" + g.group(0) +
                  ";console.log(JSON.stringify(["
                  "ghostHTML({voice: 'the archivist',"
                  " text: 'A complete summary paragraph.'}),"
                  " ghostHTML(undefined)]))")
        out = json.loads(subprocess.run(
            ["node", "-e", script],
            capture_output=True, text=True, check=True).stdout)
        self.assertIn("ghostdesk", out[0])
        self.assertIn("the archivist", out[0])
        self.assertIn("ghost desk", out[0])
        self.assertEqual(out[1], "")

    def test_edition_ghost_quiet_marker(self):
        # edition-level "ghost_quiet": one small legible line, silent
        # when the composer does not send it
        self.assertIn("ghost_quiet", self.js)
        self.assertIn("ghost desk quiet", self.js)
        for html in ("broadsheet.html", "index.html"):
            self.assertIn('id="mast-ghost"', read(html))
        css = read("broadsheet.css")
        self.assertIn(".mast-ghost", css)
        self.assertIn(".mast-ghost:empty", css)


class RefreshStaleness(unittest.TestCase):
    """The refresh button must re-fetch for real and show it (review)."""

    def setUp(self):
        self.js = read("broadsheet-view.js")

    def test_cache_busted_refetch(self):
        # fetchJSON sends cache:'no-store'; the URL param defeats any
        # intermediate proxy between page and dashboard server
        start = self.js.index("function loadFeed")
        end = self.js.index("function refresh", start)
        body = self.js[start:end]
        self.assertIn("'t=' + Date.now()", body)
        self.assertIn("fetchJSON(url2)", body)

    def test_refresh_button_shows_feedback(self):
        self.assertIn("'refreshing…'", self.js)
        self.assertIn("btn.disabled = false", self.js)
        self.assertIn("btn.textContent = old", self.js)


if __name__ == "__main__":
    unittest.main()
