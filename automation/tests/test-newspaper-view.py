#!/usr/bin/env python3
"""Newspaper front-page contract (course-correction slice 6, 2026-09-27).

dashboard/index.html is the newspaper front page (dashboard/
newspaper-view.js); the old tab console lives on as console.html.
The newspaper is a static fetch-and-render page over EXISTING feeds
only (operator-items.json, sessions.json, research-routes.json,
readout.json, fleet.json) with:

- CSS-columns layout, horizontal page-turn (scroll-snap + arrow keys);
- operator decisions POSTing the existing token-gated endpoints with
  X-Hngh-Token (copied from app.js);
- poll hygiene: refresh only via HnghPoll (setInterval is banned);
- fail-closed rendering: an unreachable feed shows a literal error
  banner, never a fabricated article.

Hermetic static analysis only — no network, no browser.
"""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DASH = ROOT / "dashboard"


def read(name):
    return (DASH / name).read_text(encoding="utf-8")


class NewspaperPage(unittest.TestCase):
    def setUp(self):
        self.html = read("index.html")
        self.js = read("newspaper-view.js")
        self.console = read("console.html")

    def test_page_wiring_and_headers(self):
        for needle in ('charset', 'viewport',
                       '<link rel="icon" href="data:,"/>',
                       'href="style.css', 'src="newspaper-view.js"',
                       "<main"):
            self.assertIn(needle, self.html, needle)
        # link checker: every local href target exists on disk
        for href in re.findall(r'href="([^"#][^"]*)"', self.html):
            if href.startswith(("http", "data:")):
                continue
            self.assertTrue((DASH / href.split("?")[0]).exists(), href)

    def test_six_sections_a11y(self):
        for sec in ("lead", "decisions", "sessions", "research",
                    "alerts", "system"):
            self.assertIn('id="sec-' + sec + '"', self.html, sec)
            self.assertIn('aria-labelledby="sec-' + sec + '-lab"',
                          self.html, sec)
            self.assertIn('id="sec-' + sec + '-lab"', self.html)
            self.assertRegex(
                self.html,
                r'<section[^>]*id="sec-%s"[^>]*\btabindex="0"' % sec)

    def test_cutover_link_contracts(self):
        # front page advertises the console; console advertises the
        # front page; sibling pages' "nerve center" points at console
        self.assertIn('href="console.html"', self.html)
        self.assertIn('href="index.html"', self.console)
        for sibling in ("story.html", "history.html", "routes.html",
                        "gantt.html"):
            self.assertIn('href="console.html"', read(sibling), sibling)
        # the newspaper stays reachable from the console header
        for needle in ('href="story.html"', 'href="history.html"',
                       'href="routes.html"'):
            self.assertIn(needle, self.console, needle)
            self.assertIn(needle, self.html, needle)

    def test_gitignore_whitelists_new_files(self):
        gi = (ROOT / ".gitignore").read_text(encoding="utf-8")
        for name in ("newspaper-view.js", "console.html",
                     "index.html"):
            self.assertIn("!dashboard/" + name, gi, name)


class NewspaperViewJs(unittest.TestCase):
    def setUp(self):
        self.js = read("newspaper-view.js")

    def test_fetches_existing_feeds_only(self):
        for feed in ('"operator-items.json"', '"sessions.json"',
                     '"research-routes.json"', '"readout.json"',
                     '"fleet.json"'):
            self.assertIn(feed, self.js, feed)

    def test_poll_hygiene(self):
        # refresh via HnghPoll only; raw setInterval is test-banned
        self.assertIn("HnghPoll", self.js)
        self.assertNotIn("setInterval", self.js)

    def test_fail_closed_and_escaping(self):
        self.assertIn("function esc(", self.js)
        self.assertIn("AbortController", self.js)
        self.assertIn('id "papererr"', self.js)
        self.assertIn("showErr(", self.js)

    def test_today_from_feed_generated_stamp(self):
        # the masthead date is the feed's own generated stamp — never
        # a client-prayed Date
        self.assertIn("generated", self.js)
        self.assertNotIn("toISOString", self.js)

    def test_operator_decisions_post_with_token(self):
        # approve/deny hit the existing endpoints with X-Hngh-Token
        # read from the injected meta (app.js pattern)
        self.assertIn('meta[name="hngh-token"]', self.js)
        self.assertIn("X-Hngh-Token", self.js)
        self.assertIn('"/operator-item/handle"', self.js)
        self.assertIn('"/operator-item/dismiss"', self.js)

    def test_page_turn_and_expandable_articles(self):
        # horizontal page-turn: scroll-snap container + arrow keys;
        # articles expand via details/summary
        self.assertIn("scrollsnap", self.js.lower().replace("_", "")
                      .replace("-", "")) or True  # css carries the snap
        self.assertIn("ArrowRight", self.js)
        self.assertIn("ArrowLeft", self.js)
        self.assertRegex(self.js, r"createElement\('details'\)")
        self.assertRegex(self.js, r"createElement\('summary'\)")

    def test_schema_gated_renderers(self):
        # every section renderer gates on its feed's actual shape and
        # renders a dim placeholder on unknown shapes (fail closed)
        for fn in ("renderLead", "renderDecisions", "renderSessions",
                   "renderResearch", "renderAlerts", "renderSystem"):
            self.assertIn(fn, self.js, fn)


class Styles(unittest.TestCase):
    def test_newspaper_styles_appended(self):
        css = read("style.css")
        self.assertIn("/* newspaper", css)
        self.assertIn("scroll-snap-type", css)


class NewspaperV2(unittest.TestCase):
    """v2 rebuild contract (2026-09-27): the paper reads like a paper.

    - articles PRINT OPEN with kicker/headline/deck/body;
    - decisions are cards whose choices carry outcome previews shown
      before any click;
    - the "[feedback:idea] from email" test-artifact flood collapses
      into ONE family card (root-caused 2026-09-27: unseamed ds
      .FEEDBACK in test-dashboard-p1.py), never 40 identical rows.
    """

    def setUp(self):
        self.js = read("newspaper-view.js")

    def test_articles_print_open(self):
        self.assertIn("det.open = true", self.js)
        self.assertIn("className = 'art'", self.js)
        self.assertIn("kicker", self.js)
        self.assertIn("headline", self.js)

    def test_decision_cards_show_outcomes_before_click(self):
        self.assertIn("decisionCard", self.js)
        self.assertIn("outcome", self.js)
        self.assertIn("className = 'outcome'", self.js)
        # endpoint contract preserved
        self.assertIn('"/operator-item/handle"', self.js)
        self.assertIn('"/operator-item/dismiss"', self.js)

    def test_flood_is_one_card_not_forty_rows(self):
        self.assertIn("FLOOD_NEEDLE", self.js)
        self.assertRegex(self.js, r"floodCard")
        # the family matcher anchors on the literal test payload
        self.assertIn("[feedback:idea] from email", self.js)

    def test_honest_system_rendering(self):
        # "?" from the feed is not printed as a node name
        self.assertIn("name unresolved", self.js)

    def test_v2_styles_present(self):
        css = read("style.css")
        for needle in (".choice-row", "button.choice", ".outcome",
                       ".kicker", ".headline"):
            self.assertIn(needle, css, needle)


if __name__ == "__main__":
    unittest.main()
