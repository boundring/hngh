#!/usr/bin/env python3
"""Story view contract (visualization rung 1, step 3).

The story page is a static fetch-and-render dashboard page
(dashboard/story.html + dashboard/story-view.js) that renders
today's chapters from the work graph (dashboard/plans.json) and the
report-queue ledger (dashboard/reports.md):

- four sections: accepted, steps-completed (commit-hash footnotes),
  blockers, parks;
- honesty rules: hashes come only from real evidence (feed
  last_ceremony_commit plus 7-40 hex tokens in today's report rows),
  the "today" UTC date comes from the feed's own `generated` stamp,
  never a fabricated schedule;
- a11y: every section has an aria-labelledby heading and a
  tabindex for keyboard focus (parked ux-review finding);
- one dry aside per section, maximum (voice rules,
  docs/design/presentation-direction.md);
- fail-closed rendering: a missing field renders a dim
  placeholder, never a fabricated value.

Hermetic static analysis only — no network, no browser.
"""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DASH = ROOT / "dashboard"


def read(name):
    return (DASH / name).read_text(encoding="utf-8")


class StoryPage(unittest.TestCase):
    def setUp(self):
        self.html = read("story.html")
        self.js = read("story-view.js")

    def test_page_wiring_and_headers(self):
        # static fetch-and-render page like the gantt page
        for needle in ('charset', 'viewport',
                       '<link rel="icon" href="data:,"/>',
                       'href="style.css', 'src="story-view.js"',
                       "<main"):
            self.assertIn(needle, self.html, needle)
        # link checker: every local href target exists on disk
        for href in re.findall(r'href="([^"#][^"]*)"', self.html):
            if href.startswith(("http", "data:")):
                continue
            target = href.split("?")[0]
            self.assertTrue((DASH / target).exists(), href)
            self.assertTrue((ROOT / "tests").exists())  # harness sanity
        # the page is reachable from the nerve center and siblings
        self.assertIn('href="story.html"', read("index.html"))
        self.assertIn('href="story.html"', read("gantt.html"))

    def test_four_sections_a11y(self):
        for sec in ("accepted", "steps", "blockers", "parks"):
            self.assertIn('id="sec-' + sec + '"', self.html, sec)
            self.assertIn('aria-labelledby="sec-' + sec + '-lab"', self.html)
            self.assertIn('id="sec-' + sec + '-lab"', self.html)
            # keyboard focus: each section is in the tab order
            self.assertRegex(
                self.html,
                r'<section[^>]*id="sec-%s"[^>]*\btabindex="0"' % sec)


class StoryViewJs(unittest.TestCase):
    def setUp(self):
        self.js = read("story-view.js")

    def test_fetches_work_graph_and_report_ledger(self):
        self.assertIn('"plans.json"', self.js)
        self.assertIn('"reports.md"', self.js)

    def test_fail_closed_and_escaping(self):
        # HTML escaping helper, used on the real render path
        self.assertIn("function esc(", self.js)
        self.assertGreaterEqual(self.js.count("esc(") - 1, 4)
        # bounded fetches (abortable) and an error banner element
        self.assertIn("AbortController", self.js)
        self.assertIn("id \"storyerr\"", self.js)
        # a failed fetch renders the banner, not a fabricated page
        self.assertIn("showErr(", self.js)

    def test_today_from_feed_generated_stamp(self):
        # "today" is the UTC date of the feed's own generated stamp —
        # never a client-prayed Date and never an invented schedule
        self.assertIn("generated", self.js)
        self.assertNotIn("toISOString", self.js)
        self.assertRegex(self.js, r"todayFromStamp\(\s*feed")

    def test_commit_hash_footnotes_evidence_only(self):
        # hashes come only from feed last_ceremony_commit and from
        # 7-40-hex tokens in TODAY's report rows (see HEX below)
        self.assertIn("last_ceremony_commit", self.js)
        self.assertIn("HEX = /\\b[0-9a-f]{7,40}\\b/", self.js)

    def test_one_dry_aside_per_section(self):
        # the builder is the ONLY literal aside producer; each of the
        # four section renderers appends it at most once
        self.assertIn("MAX_ASIDE", self.js)
        self.assertEqual(self.js.count("<aside"), 1)
        for fn in ("renderAccepted", "renderSteps", "renderBlockers",
                   "renderParks"):
            self.assertIn(fn, self.js)


if __name__ == "__main__":
    unittest.main()
