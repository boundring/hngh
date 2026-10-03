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


class SettleReceipt(unittest.TestCase):
    """The settlement receipt: after a successful verb post the page
    names the ledgers the decision (and note) hit -- the card itself
    is filtered from the stream, so the receipt is the only feedback
    that survives the rebuild."""

    def setUp(self):
        self.js = read("broadsheet-view.js")

    def _fn(self, name):
        m = re.search(r"function %s\([a-z, ]*\) \{[\s\S]*?\n  \}" % name,
                      self.js)
        self.assertTrue(m, name + " missing")
        return m.group(0)

    def test_wiring_and_style(self):
        self.assertIn("settleReceipt(act.endpoint, payload)", self.js)
        self.assertNotIn(
            ".then(function () { rebuildStream(); })", self.js)
        css = read("broadsheet.css")
        self.assertIn("#settle-receipt", css)
        self.assertIn("#settle-receipt.on", css)

    def _receipt(self, endpoint, item_id, note):
        esc = re.search(r"function esc\(s\) \{[\s\S]*?\n  \}", self.js)
        self.assertTrue(esc, "esc missing")
        script = (esc.group(0) + "\n" + self._fn("ledgerSide") + "\n" +
                  self._fn("receiptText") +
                  "\nconsole.log(JSON.stringify(receiptText(" +
                  json.dumps(endpoint) + ", " + json.dumps(item_id) +
                  ", " + json.dumps(note) + ")))")
        return json.loads(subprocess.run(
            ["node", "-e", script],
            capture_output=True, text=True,
            check=True).stdout.strip())

    def test_park_receipt(self):
        t = self._receipt("/operator-item/park", "faa648fe",
                          "filed as backlog debt")
        self.assertIn("park settled — faa648fe", t)
        self.assertIn("operator-item:faa648fe:parked", t)
        self.assertIn("dismissed-side ledger", t)
        self.assertIn('your note: "filed as backlog debt"', t)
        self.assertIn("the card leaves the next edition", t)

    def test_acknowledge_and_silent_verbs(self):
        t = self._receipt("/operator-item/acknowledge", "ff2f2a18",
                          "leave open for the sweep")
        self.assertIn("operator-item:ff2f2a18:acknowledged", t)
        self.assertIn("approved-side ledger", t)
        t = self._receipt("/operator-item/dismiss", "37bc583b", None)
        self.assertIn("dismiss settled — 37bc583b", t)
        self.assertNotIn("your note", t)


class OperatorGuidance(unittest.TestCase):
    """Guidance blocks render from the feed payload only, fail open."""

    G = {
        "why": "the operator is the only seam owner",
        "note_rules": "note <=200 chars; '|' stripped",
        "verbs": [
            {"verb": "park", "label": "Park", "note": "required",
             "effect": "row parked; note recorded in the ledger",
             "examples": [{"note": "waiting on unsloth slot",
                           "effect": "parked row carries the note"}]},
            {"verb": "acknowledge", "label": "Acknowledge",
             "note": "optional", "effect": "approved-side ledger row",
             "examples": []},
            {"verb": "dismiss", "label": "Dismiss", "note": None,
             "effect": "dismissed-side ledger row", "examples": []},
        ],
        "docs": [
            {"label": "kernel doc", "path": "docs/research/foo.md"},
            {"label": "readme", "path": "automation/README.md"},
        ],
    }

    def setUp(self):
        self.js = read("broadsheet-view.js")

    def run_guidance(self, *calls):
        esc = re.search(r"function esc\(s\) \{[\s\S]*?\n  \}", self.js)
        g = re.search(r"function guidanceHTML\(g\) \{[\s\S]*?\n  \}", self.js)
        self.assertTrue(esc and g, "esc/guidanceHTML missing")
        script = ("var G = " + json.dumps(self.G) + ";\n" +
                  esc.group(0) + "\n" + g.group(0) +
                  ";console.log(JSON.stringify([" + calls[0] + "]))")
        return json.loads(subprocess.run(
            ["node", "-e", script],
            capture_output=True, text=True, check=True).stdout)[0]

    def test_wiring_and_style(self):
        self.assertIn("guidanceHTML(a.guidance)", self.js)
        css = read("broadsheet.css")
        self.assertIn(".oguide", css)
        self.assertIn(".art.expanded .oguide", css)

    def test_note_semantics_pin(self):
        # guidance display must mirror the endpoints' note contract
        self.assertIn("'/operator-item/park': 'required'", self.js)
        self.assertIn("'/operator-item/acknowledge': 'optional'", self.js)

    def test_renders_when_present(self):
        out = self.run_guidance("guidanceHTML(G)")
        self.assertIn("oguide", out)
        self.assertIn("the operator is the only seam owner", out)
        self.assertIn("note &lt;=200 chars", out)
        # one row per verb: label / note requirement / durable effect
        self.assertIn("<td>Park</td><td class=\"og-need\">required</td>", out)
        self.assertIn("<td>Acknowledge</td>"
                      "<td class=\"og-need\">optional</td>", out)
        self.assertIn("<td>Dismiss</td><td class=\"og-need\">-</td>", out)
        self.assertIn("row parked; note recorded in the ledger", out)
        self.assertIn("dismissed-side ledger row", out)
        # example notes: note text + what filing it causes
        self.assertIn("&quot;waiting on unsloth slot&quot;", out)
        self.assertIn("parked row carries the note", out)
        # docs: docs/ path earns the jailed href, others plain text
        self.assertIn('<a href="/hngh-docs/docs/docs%2Fresearch%2Ffoo.md">', out)
        self.assertIn("readme: automation/README.md", out)
        self.assertNotIn("automation/README.md</a>", out)

    def test_fail_open_when_absent(self):
        # absent/empty guidance renders exactly nothing (byte no-op)
        self.assertEqual(self.run_guidance("guidanceHTML(undefined)"), "")
        self.assertEqual(self.run_guidance("guidanceHTML({})"), "")


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

    def test_refresh_triggers_full_rebuild(self):
        # the cache-busted refetch must actually re-print the sheet:
        # the button path rebuilds the stream, the silent 30s poll
        # deliberately does not (that rebuild-from-stale-snapshot was
        # the original flash bug)
        self.assertIn("refresh(true)", self.js)
        self.assertIn("function loadFeed(rebuild)", self.js)
        # slice 3: the silent poll rebuilds ONLY on a changed edition
        # stamp (freshEdition); unchanged snapshots keep the old rule
        self.assertIn("if (rebuild || freshEdition || "
                      "!$('stream').childNodes.length)", self.js)
        self.assertIn("rebuildStream(true);", self.js)
        # poll chain keeps the no-rebuild semantics
        self.assertIn("Promise.resolve(refresh()).then", self.js)

    def test_fail_stale_keeps_current_edition(self):
        # a rejected refetch shows the banner and must not blank the
        # page: loadFeed throws before touching feed.data, and the
        # refresh rejection path never rebuilds
        start = self.js.index("function loadFeed")
        feed_data = self.js.index("feed.data = d", start)
        throw = self.js.index("refusing to print a blank page", start)
        self.assertLess(throw, feed_data,
                        "malformed feed must not replace feed.data")
        rstart = self.js.index("function refresh")
        rend = self.js.index("// ---------- column config", rstart)
        rejected = self.js[rstart:rend]
        self.assertIn("showErr(rs[0].reason.message)", rejected)
        self.assertNotIn("rebuildStream(", rejected[rejected.index("rejected"):])


ESC_RE = r"function esc\(s\) \{[\s\S]*?\n  \}"


class ComposerWidgets(unittest.TestCase):
    """Composer/server contract fields (2026-09-29): fire, narrative,
    embed, parked, omp session. The view codes fail-open: an absent
    field renders nothing and never breaks the card."""

    def setUp(self):
        self.js = read("broadsheet-view.js")
        self.html = read("broadsheet.html")
        self.css = read("broadsheet.css")

    def _fn(self, name):
        m = re.search(r"function %s\([a-z, ]*\) \{[\s\S]*?\n  \}" % name,
                      self.js)
        self.assertTrue(m, name + " missing")
        return m.group(0)

    def _node(self, expr, *fns):
        script = "\n".join(fns) + \
            ";console.log(JSON.stringify(" + expr + "))"
        return json.loads(subprocess.run(
            ["node", "-e", script],
            capture_output=True, text=True, check=True).stdout)

    # ---- fire ----
    def test_fire_button_wiring_payload_receipt(self):
        # fail-open gate: no endpoint string, no button
        self.assertIn("typeof fire.endpoint === 'string'", self.js)
        self.assertIn("{ id: a.id, note: fire.note }", self.js)
        # receipt via the settle chip pattern, esc'd override text
        settle = self._fn("settleReceipt")
        self.assertIn("esc(override ||", settle)
        self.assertIn(
            "'fired ' + (fire.verb || '?') + ' — ' + (fire.effect || '')",
            self.js)
        self.assertIn("settleReceipt(fire.endpoint, payload,", self.js)

    # ---- narrative ----
    def test_narrative_renders_line_and_place(self):
        out = self._node(
            "[narrativeHTML({place: 'below',"
            " line: 'the seam owner walked the floor'}),"
            " narrativeHTML({place: 'above', line: 'x'}),"
            " narrativeHTML(undefined), narrativeHTML({}),"
            " narrativeHTML({place: 'below'})]",
            re.search(ESC_RE, self.js).group(0), self._fn("narrativeHTML"))
        self.assertIn("art-narrative", out[0])
        self.assertIn("narr-below", out[0])
        self.assertIn("the seam owner walked the floor", out[0])
        self.assertIn("narr-above", out[1])
        for empty in out[2:]:
            self.assertEqual(empty, "")

    def test_narrative_wiring_and_style(self):
        self.assertIn("narrativeHTML(a.narrative)", self.js)
        self.assertIn(".art-narrative", self.css)
        self.assertIn(".art.expanded .art-narrative", self.css)

    def test_srcline_supporting_info_expanded_only(self):
        # supporting info stays out of the collapsed card: the source
        # line reveals with the expanded context (ink-reveal parity)
        self.assertIn(".art .srcline { display: none;", self.css)
        self.assertIn(".art.expanded .srcline", self.css)

    # ---- embed ----
    def test_embed_btop_poll_start_stop(self):
        self.assertIn("kind === 'btop'", self.js)  # unknown kinds: nothing
        self.assertIn("'btop-embed'", self.js)
        self.assertIn("embedSync(art, a)", self.js)
        self.assertIn("fetchText(a.embed.src, 4000)", self.js)
        # chained 2s poll while expanded; a BARE clearInterval stops it
        self.assertIn("setTimeout(loop, 2000)", self.js)
        self.assertRegex(self.js, r"(?m)^\s+clearInterval\(pre\._embT\);$")
        # rebuilt/trimmed cards stop polling with their node
        self.assertIn("!pre.isConnected", self.js)

    def test_embed_style_and_alt(self):
        self.assertIn(".btop-embed", self.css)
        self.assertIn(".art.expanded .btop-embed", self.css)
        self.assertIn("a.embed.alt || 'btop'", self.js)

    # ---- parked shelf ----
    def test_shelf_renders_parked_rows(self):
        self.assertIn('id="parked-shelf"', self.html)
        self.assertIn('class="parked-shelf"', self.html)
        self.assertIn(".parked-shelf", self.css)
        self.assertIn("Array.isArray(a && a.parked)", self.js)
        out = self._node(
            "[shelfStrip({id: 'aa', ts: '2026-09-29T12:34:56Z',"
            " why: 'waiting on unsloth slot'}),"
            " shelfStrip({why: 'x' * 100}), shelfStrip(null)]",
            re.search(ESC_RE, self.js).group(0), self._fn("shelfStrip"))
        self.assertIn("parked-strip", out[0])
        self.assertIn("2026-09-29T12:34", out[0])
        self.assertIn("waiting on unsloth slot", out[0])
        self.assertNotIn("x" * 49, out[1])  # why truncated to fit the rail
        self.assertIn("parked-strip", out[2])  # null row strips, no crash
        self.assertIn("shelfRender()", self.js)

    def test_park_flies_to_shelf_before_rebuild(self):
        choices = self._fn("choicesEl")
        self.assertIn("parkFly(bar.closest('article'), payload)", choices)
        self.assertIn(
            "setTimeout(function () { rebuildStream(true); }, 520)", choices)
        fly = self._fn("parkFly")
        self.assertIn("prefers-reduced-motion", fly)
        self.assertIn("getBoundingClientRect", fly)

    # ---- omp session ----
    def test_omp_session_button_fail_visible(self):
        self.assertIn("postJson('/article/omp-session', { id: a.id })",
                      self.js)
        self.assertIn("j.path || j.package", self.js)
        self.assertIn("j.command", self.js)
        # 503: the launcher's command string is shown, never swallowed
        self.assertIn("e.body.command", self.js)
        self.assertIn("'launcher unavailable — run: '", self.js)
        self.assertIn("err.body = j", self.js)  # postJson surfaces the body
        self.assertIn("ompBtnEl(a)", self.js)
        self.assertIn(".omp-btn", self.css)
        self.assertIn(".art.expanded .omp-btn", self.css)


class MotionLayer(unittest.TestCase):
    """Insert rise, expand reveal, rip burst, park fly, the folded-paper
    #megastructure, and the reduced-motion kill switch."""

    def setUp(self):
        self.js = read("broadsheet-view.js")
        self.html = read("broadsheet.html")
        self.css = read("broadsheet.css")

    def _fn(self, name):
        m = re.search(r"function %s\([a-z, ]*\) \{[\s\S]*?\n  \}" % name,
                      self.js)
        self.assertTrue(m, name + " missing")
        return m.group(0)

    def test_insert_animation_delay_variety(self):
        self.assertIn("art-rise", self.css)
        self.assertIn("animation-delay: var(--rise-d, 0ms)", self.css)
        self.assertIn("'--rise-d'", self.js)
        self.assertIn("h32(String(a.id || '')) % 5", self.js)

    def test_rip_burst_on_settle(self):
        self.assertIn("ripBurst(bar.closest('article'))",
                      self._fn("choicesEl"))
        rip = self._fn("ripBurst")
        self.assertIn("prefers-reduced-motion", rip)
        self.assertIn("'rip rip' + i", rip)
        self.assertIn("animationend", rip)
        self.assertIn(".rip", self.css)
        self.assertIn("@keyframes rip-fly", self.css)

    def test_megastructure_folded_planes_and_tilt(self):
        self.assertIn('id="megastructure"', self.html)
        self.assertEqual(self.html.count('class="mf mf'), 5)  # 4-6 faces
        self.assertIn("preserve-3d", self.css)
        self.assertIn("@keyframes mega-sway", self.css)
        self.assertIn("#megastructure.tilt .mega-tilt", self.css)
        self.assertIn("megaTilt();", self.js)
        self.assertIn("classList.add('tilt')", self.js)
        self.assertIn("width: 180px", self.css)
        self.assertIn("bottom: 12px", self.css)

    def test_reduced_motion_kills_motion_layer(self):
        m = re.search(
            r"@media \(prefers-reduced-motion: reduce\) \{[\s\S]*?\n\}",
            self.css)
        self.assertTrue(m, "reduced-motion guard missing")
        block = m.group(0)
        for needle in (".art", ".mega-fold", ".rip", ".park-fly",
                       "animation: none", "transition: none"):
            self.assertIn(needle, block)

    def test_fail_open_without_new_fields(self):
        # every new widget is gated on its field; legacy cards render
        # exactly as before
        self.assertIn(
            "(Array.isArray(a.choices) && a.choices.length) || a.fire",
            self.js)
        self.assertIn("narrativeHTML(a.narrative)", self.js)
        self.assertIn("kind === 'btop'", self.js)
        self.assertIn("Array.isArray(a && a.parked)", self.js)




class HandledInPlace(unittest.TestCase):
    """Handle/acknowledge leave the card on the sheet but visibly marked
    (tranche 2026-10-03 slice 2). The click already rebuilt the stream —
    from the same stale composer snapshot, so the card returned
    identical and the click read as a no-op. Contract: APPROVED-side
    verbs mark the card in place (dim + chip) via a persistent store;
    DISMISSED-side verbs keep the existing filter (gone on rebuild).
    """

    def setUp(self):
        self.js = read("broadsheet-view.js")

    def test_handled_store_mirrors_dismissed_pattern(self):
        self.assertIn("'broadsheet-handled'", self.js)
        self.assertIn("handledPersist(id)", self.js)
        self.assertIn("feed.handled[id] = true", self.js)

    def test_verb_store_maps_ledger_sides(self):
        m = re.search(r"function verbStore\(endpoint\) \{[\s\S]*?\n  \}",
                      self.js)
        self.assertTrue(m, "verbStore missing")
        script = ("function handledPersist() {}; function dismissPersist() {};\n"
                  + m.group(0) +
                  ";console.log(JSON.stringify(["
                  "verbStore('/operator-item/handle') === handledPersist,"
                  "verbStore('/operator-item/acknowledge') === handledPersist,"
                  "verbStore('/operator-item/dismiss') === dismissPersist,"
                  "verbStore('/operator-item/park') === dismissPersist,"
                  "verbStore('/operator-item/expire') === dismissPersist,"
                  "verbStore('/operator-item/suppress') === dismissPersist,"
                  "verbStore('/flag')]))")
        out = json.loads(subprocess.run(
            ["node", "-e", script], capture_output=True, text=True,
            check=True).stdout)
        self.assertEqual(out, [True, True, True, True, True, True, None])

    def test_card_marks_handled_in_place(self):
        self.assertIn("feed.handled[a.id]", self.js)
        self.assertIn("classList.add('ohandled')", self.js)
        self.assertIn("ohandled-chip", self.js)
        self.assertIn("handled \u2713 \u2014 leaves the next edition", self.js)

    def test_success_handler_persists_before_feedback(self):
        # both the choice click and the fire path route through verbStore
        self.assertIn("var persist = verbStore(act.endpoint);", self.js)
        self.assertIn("var persist = verbStore(fire.endpoint);", self.js)
        self.assertIn("if (persist) persist(a.id);", self.js)

    def test_dismiss_drops_card_from_cached_feed_now(self):
        # the refetch dismissed-filter only runs on the next poll; the
        # receipt promises the card leaves THIS rebuild — drop it from
        # feed.data before rebuilding (live 2026-10-03: card lingered
        # up to 30s after "dismiss settled")
        self.assertIn("persist === dismissPersist", self.js)
        self.assertIn("feed.data.articles = feed.data.articles.filter",
                      self.js)
        self.assertIn("x.id !== a.id", self.js)

    def test_persist_keys_on_article_id_not_payload(self):
        # choice actions carry act.payload.id = OPERATOR-ITEM id; cards
        # are keyed by the ARTICLE id (a.id). Persisting payload.id made
        # the mark never match the rendered card (live 2026-10-03).
        self.assertNotIn("persist(payload.id)", self.js)

    def test_css_marks_decided_cards(self):
        css = read("broadsheet.css")
        self.assertIn(".art.ohandled", css)
        self.assertIn(".ohandled-chip", css)




class EditionAwarePoll(unittest.TestCase):
    """Tranche 2026-10-03 slice 3: the silent 30s poll must rebuild the
    sheet when the composer stamps a NEW edition (otherwise an open tab
    reads the same paper all day), the dateline must carry the edition
    age + open-item count, and an unchanged snapshot still never
    rebuilds (the original flash bug)."""

    def setUp(self):
        self.js = read("broadsheet-view.js")

    def test_rebuild_stamps_and_compares_generated(self):
        self.assertIn("feed.renderedGenerated = (feed.data || {}).generated;",
                      self.js)
        self.assertIn("d.generated !== feed.renderedGenerated", self.js)

    def test_refresh_fetches_open_count(self):
        self.assertIn("fetchJSON('operator-items.json')", self.js)
        self.assertIn("feed.openCount", self.js)

    def test_edition_line_carries_age_and_open(self):
        self.assertIn("function editionAge(", self.js)
        self.assertIn("'stale edition \u00b7 '", self.js)
        self.assertIn("feed.openCount + ' open'", self.js)

    def test_age_reads_feed_root_generated(self):
        # the stamp lives at the feed root, NOT inside edition{} — the
        # first cut read ed.generated (always undefined, age never shown)
        self.assertIn("editionAge(feed.data && feed.data.generated,",
                      self.js)

    def test_edition_age_math(self):
        m = re.search(r"function editionAge\([\s\S]*?\n  \}", self.js)
        self.assertTrue(m, "editionAge missing")
        script = m.group(0) + (
            ";var t0 = Date.parse('2026-10-03T14:44:42Z');"
            "console.log(JSON.stringify(["
            "editionAge('2026-10-03T14:44:42Z', t0 + 12 * 60000),"
            "editionAge('2026-10-03T14:44:42Z', t0 + 96 * 60000),"
            "editionAge('2026-10-03T14:44:42Z', t0),"
            "editionAge('garbage', t0)]))")
        out = json.loads(subprocess.run(
            ["node", "-e", script], capture_output=True, text=True,
            check=True).stdout)
        self.assertEqual(out, [
            {"text": "12m old", "stale": False},
            {"text": "1h 36m old", "stale": True},
            {"text": "0m old", "stale": False},
            None])




class VerbTitles(unittest.TestCase):
    """Tranche 2026-10-03 slice 4: every decision button names its
    outcome — the front page's verb buttons had no title/aria-label at
    all, so a scanning operator had to know the grammar cold."""

    def setUp(self):
        self.js = read("broadsheet-view.js")

    def test_choice_buttons_carry_outcome(self):
        self.assertIn("b.title = ch.outcome;", self.js)
        self.assertIn("b.setAttribute('aria-label',", self.js)

    def test_fire_button_titled(self):
        self.assertIn("fb.title = 'fire: dispatches this article verb now';",
                      self.js)
        self.assertIn("fb.setAttribute('aria-label', fb.title);", self.js)

    def test_omp_button_titled(self):
        self.assertIn(
            "b.title = 'opens an omp session in a terminal bound to this"
            " article';", self.js)


class GuidanceProgressiveReveal(unittest.TestCase):
    """Tranche 2026-10-03 slice 4: the guidance card shows its one-line
    why at rest (cause-and-effect without opening every article); the
    verb table, rules, and docs unfold with the expanded article."""

    def setUp(self):
        self.css = read("broadsheet.css")

    def test_why_visible_rest_blocks_hidden(self):
        self.assertIn(".oguide .og-table, .oguide .og-rules, "
                      ".oguide .og-docs { display: none; }", self.css)

    def test_expanded_reveals_blocks(self):
        self.assertIn(".art.expanded .oguide .og-table { display: table; }",
                      self.css)
        self.assertIn(".art.expanded .oguide .og-rules,", self.css)
        self.assertIn(".art.expanded .oguide .og-docs { display: block; }",
                      self.css)




class ConsoleHistoryRows(unittest.TestCase):
    """Tranche 2026-10-03 slice 5: the console History tab rendered a
    full status line ("204 entries · 204 shown") but zero rows —
    setBody wrote #hist-body, which exists only in standalone
    history.html; tab mounts ship a bare #history-root and got nothing.
    """

    def setUp(self):
        self.js = read("history-view.js")

    def test_init_builds_toolbar_and_body_for_tab_mounts(self):
        self.assertIn("bar = document.createElement('div');", self.js)
        self.assertIn("bar.className = 'hv-toolbar';", self.js)
        self.assertIn("rows.id = 'hist-body';", self.js)
        self.assertIn("el.appendChild(rows);", self.js)




class TokenFailSafe(unittest.TestCase):
    """Tranche 2026-10-03: the served page carries two hngh-token metas
    (server-injected real one, then the empty file:// placeholder).
    querySelector stops at the first match in document order, which is
    fine served but wrong on any page order change; read the first
    NON-EMPTY content across all matches instead."""

    def test_first_non_empty_across_all_views(self):
        qsa = "querySelectorAll('meta[name=" + '"' + "hngh-token" + '"' + "]')"
        qs = "document.querySelector('meta[name=" + '"' + "hngh-token" + '"' + "]')"
        for name in ("broadsheet-view.js", "app.js", "desk-view.js"):
            js = read(name)
            self.assertIn(qsa, js, name)
            self.assertNotIn(qs, js, name)
            self.assertIn("if (v) return v;", js, name)


if __name__ == "__main__":
    unittest.main()
