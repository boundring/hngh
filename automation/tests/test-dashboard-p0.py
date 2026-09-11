#!/usr/bin/env python3
"""Dashboard P0 wave (review 2026-09-11 §5) contract tests, hermetic.

dashboard/ UI files are gitignored runtime artifacts, so the honest tracked
regression is a textual contract on the served sources — same discipline as
test-plan-acceptance.PlansViewContract and test-readout-writers.py. Asserts
what a browser observes indirectly: the token value, the probe-first link
shape, the poll helper's pause/backoff, the title badge, and the layout
values. No network, no server, no dashboard files written.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DASH = ROOT / "dashboard"


def src(name):
    return (DASH / name).read_text()


class ContrastToken(unittest.TestCase):
    def test_dim_meets_wcag_aa(self):
        css = src("style.css")
        m = re.search(r"--dim:\s*(#[0-9a-fA-F]{6})", css)
        self.assertIsNotNone(m, "--dim token missing")
        self.assertEqual(m.group(1).lower(), "#6e7681")
        self.assertNotIn("#484f58", css, "old 2.28:1 dim value still hardcoded")

    def test_no_view_hardcodes_old_dim(self):
        for js in DASH.glob("*.js"):
            self.assertNotIn("#484f58", js.read_text(), str(js))


class OverviewDispatchProbe(unittest.TestCase):
    def test_link_is_probe_first_fail_closed(self):
        v = src("overview-view.js")
        self.assertNotRegex(
            v, r"href=\"/digest/.*\.md\"[^>]*>full dispatch",
            "link must not be rendered unconditionally")
        self.assertIn("fetch(digestUrl", v)
        self.assertLess(v.index("r.ok"), v.index("appendChild"),
                        "link appended only after a 200 probe")


class PlansSearchFilterSort(unittest.TestCase):
    def test_search_chips_sort_and_row_link(self):
        v = src("plans-view.js")
        for field in ("queue_next", "last_ceremony_commit", "plans"):  # old contract
            self.assertIn(field, v)
        self.assertIn("pl-search", v)
        for chip in ("proposed", "accepted", "executing", "executed", "parked"):
            self.assertIn(chip, v)
        # newest-first: accepted desc, slug fallback
        self.assertLess(v.index("tb - ta"), v.index("localeCompare"))
        self.assertIn("docs/project/plans/", v)

    def test_filter_state_survives_refresh_and_keeps_focus(self):
        v = src("plans-view.js")
        self.assertIn("ui = { q: '', status: '' }", v)
        self.assertIn("value=\"' + esc(ui.q)", v, "search value restored on re-render")
        self.assertIn("renderRows(); // rows-only: focus kept", v)


class PollHygiene(unittest.TestCase):
    def test_shared_poll_helper_pauses_and_backs_off(self):
        a = src("app.js")
        self.assertIn("window.HnghPoll", a)
        self.assertIn("visibilitychange", a)
        self.assertIn("document.hidden", a)
        self.assertIn("60000", a, "backoff cap 60s")
        self.assertLess(a.index("delay * 2"), a.index("60000"), "exponential then cap")

    def test_every_view_timer_goes_through_the_helper(self):
        for name, fn in (("sessions-view.js", "fetch"),
                         ("schedule-view.js", "refresh"),
                         ("system-view.js", "refresh"),
                         ("research-view.js", "load")):
            v = src(name)
            self.assertNotIn("setInterval(", v, name + " still has a raw timer")
            self.assertIn("HnghPoll.start(" + fn, v)
        self.assertNotRegex(src("app.js")[src("app.js").index("spin up"):],
                            r"setInterval\(load")

    def test_refresh_button_refreshes_mounted_view(self):
        self.assertIn("refreshCurrentView", src("app.js"))


class TitleBadge(unittest.TestCase):
    def test_badge_mirrors_open_operator_items(self):
        a = src("app.js")
        self.assertIn("document.title = openOp > 0", a)
        self.assertIn("'(' + openOp + ') hngh'", a)


class LayoutTightening(unittest.TestCase):
    def test_density_floor_11px(self):
        self.assertNotIn("9.5px", src("style.css"))
        self.assertNotIn("9.5px", src("system-view.js"))

    def test_spacing_values(self):
        css = src("style.css")
        self.assertIn("#grid { padding: 0 16px 20px; }", css)
        ov = src("overview-view.js")
        self.assertIn(".ov{max-width:1320px}", ov)
        self.assertIn(".ov-block{margin:0 0 10px}", ov)

    def test_fixed_height_panes_become_min_max(self):
        for name in ("sessions-view.js", "kb-view.js"):
            v = src(name)
            self.assertIn("max-height:calc(100dvh - 120px)", v)
            self.assertNotIn("height:calc(100vh - 120px)", v)


if __name__ == "__main__":
    unittest.main()
