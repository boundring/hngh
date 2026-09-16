#!/usr/bin/env python3
"""digest-html newspaper rendering, hermetic.

Tests the /digest-html/ GET routes over a real bound ThreadingHTTPServer
(same pattern as test-dashboard-feedback.py) and the renderer/builder
against fixture feeds: a fixture daily digest, a fixture telemetry.db,
research-beat captures, budget log, plans.json, operator items,
research-lines.tsv and STATE.md — all seamed into tmp dirs. No real
digest or telemetry data touched, no network beyond localhost.
"""
import http.client
import importlib.util
import json
import os
import sqlite3
import sys
import tempfile
import threading
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent  # automation/


def _load(name, rel):
    spec = importlib.util.spec_from_file_location(name, str(ROOT / rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


ds = _load("dashboard_server", "dashboard-server.py")
dh = _load("digest_html", "jobs/digest-html.py")
dl = _load("digest_ledger", "jobs/digest-ledger.py")

DAY = "2026-09-11"
FIXTURE_DIGEST = """\
## 0300 {day}
_sources: hn-topstories,phoronix | model: fixture-model_
CRITICAL: Fixture routerOS privilege escalation (https://example.test/cve).
NOTABLE: Fixture linker rewritten in Rust (https://example.test/rust).
CONTEXT: Fixture index value is 56 labeled "Greed".

## 0900 {day}
_sources: claude-status | model: fixture-model_
none — quiet window

### NEWS FROM THE MEGASTRUCTURE {day}

<!-- feeds: dashboard/telemetry.db -->
- spend: $1.25 metered across 2 calls today; tokens in 3000, out 400.
""".format(day=DAY)

# Render-layer leak fixture (llc-gate-render-layer-scrub, red-first):
# pathy text injected BELOW the digest-ledger builder — the shape a
# patrol.py morning-rounds append or any future direct writer produces.
# The ledger's own scrub never sees these lines; the render seam must
# be the guard that keeps host paths out of the three egress surfaces:
# the newspaper page (/digest-html/ route), the operator email HTML
# part, and the public edition.
PATHY_LINES = (
    "### NEWS FROM THE MEGASTRUCTURE {day}\n"
    "\n"
    "- credential credential-freshness: hash-mismatch: unsloth-session "
    "(evidence ~/.hngh-automation/unsloth.token)\n"
    "## The rounds 2026-09-11\n"
    "rounds: 4 ok, 1 fail — probe wrote /tmp/hngh-probe/store.db then "
    "recovered, config at ~/Projects/etc/hngh/config\n"
    "https://example.test/runs/42 stays a URL\n"
).format(day=DAY)


def _pathy_digest(base_text):
    """Base fixture + a below-ledger pathy append (writer-sim shape)."""
    return base_text + "\n" + PATHY_LINES


def assert_no_path_tokens(testcase, html_text):
    """The render-seam law: no /home/, /tmp/, ~/ token survives any
    egress render of DIGEST CONTENT; the fixed [redacted path] marker
    stands in; the URL-shaped token survives untouched (one identity
    seam). Callers pass the content region of the render — the
    renderers' own chrome literals (masthead pointers like
    ~/.hngh/archive/digest/<date>.md) are machine-written constants,
    not digest text, and stay out of scope (see the slice record)."""
    for token in ("/home/", "/tmp/", "~/"):
        testcase.assertNotIn(token, html_text)
    testcase.assertIn("[redacted path]", html_text)
    testcase.assertIn("https://example.test/runs/42", html_text)


class Fixture:
    """Seams a tmp automation root: digest dir, telemetry.db, feeds."""

    def __enter__(self):
        self.tmp = Path(tempfile.mkdtemp())
        digest_dir = self.tmp / "digest"
        digest_dir.mkdir()
        (digest_dir / (DAY + ".md")).write_text(FIXTURE_DIGEST)
        (digest_dir / ("RESEARCH-BEAT-" + DAY + "-ctx-fixture.md")) \
            .write_text("# research beat\n\nLine one has a fact.\n"
                        "Second sentence grounds it. Third sentence. "
                        "Fourth sentence should not appear.\n")
        db = self.tmp / "telemetry.db"
        conn = sqlite3.connect(db)
        conn.execute(
            "CREATE TABLE events(ts TEXT, source TEXT, kind TEXT,"
            " identity TEXT, lane TEXT, unit TEXT, model TEXT,"
            " tokens_in INTEGER, tokens_out INTEGER, cost_usd REAL,"
            " wall_s REAL, subject TEXT, refs TEXT, body TEXT)")
        conn.executemany(
            "INSERT INTO events(ts, source, kind, tokens_in, cost_usd)"
            " VALUES(?,?,?,?,?)",
            [("2026-09-11T03:%02d:00Z" % m, "leg", "model", 1000, 0.30)
             for m in range(2)]
            + [("2026-09-11T09:15:00Z", "leg", "model", 5000, 0.75)]
            + [("2026-09-11T09:%02d:00Z" % m, "research-beat", "research",
                None, None) for m in (0, 30)])
        conn.commit()
        conn.close()
        (self.tmp / "logs").mkdir()
        (self.tmp / "logs" / "budget.md").write_text(
            "%sT01:00:00Z | overnight|fixture-plan | session-run\n"
            "%sT02:00:00Z | overnight|fixture-plan | session-run\n" % (DAY, DAY))
        (self.tmp / "dashboard").mkdir()
        (self.tmp / "dashboard" / "plans.json").write_text(json.dumps(
            {"generated": "", "queue_next": "fixture-queue",
             "last_ceremony_commit": "", "plans": [
                 {"slug": "fixture-a", "status": "executed",
                  "accepted": DAY + "T10:00:00Z", "steps_total": 2,
                  "steps_done": 2}]}))
        (self.tmp / "dashboard" / "operator-items.json").write_text(
            json.dumps({"generated_at": "", "items": [
                {"id": "aa", "text": "fixture alert row", "status": "open",
                 "first_seen": DAY + "T01:00:00Z", "last_seen": ""}]}))
        (self.tmp / "research-lines.tsv").write_text(
            "slug-a\tplanned\t%sT00:00:00Z\td\n"
            "slug-b\treviewed\t%sT00:00:00Z\td\n" % (DAY, DAY))
        (self.tmp / "STATE.md").write_text(
            "%sT00:30:00Z | 23-bctx-canary.sh | alert | fixture-drift\n"
            % DAY)
        return self

    def __exit__(self, *exc):
        import shutil
        shutil.rmtree(self.tmp, ignore_errors=True)


class RendererTest(unittest.TestCase):
    """digest-html.py: masthead, sparkline path data, stat numbers."""

    def test_render_page(self):
        with Fixture() as fx:
            dh.DIGESTS = str(fx.tmp / "digest")
            dh.TELEMETRY = str(fx.tmp / "telemetry.db")
            page = dh.render_page(str(fx.tmp / "digest" / (DAY + ".md")),
                                  dh.DIGESTS, dh.TELEMETRY)
        page.encode("ascii")
        for needle in ("The Machine Hall", "Deck A", "Deck B",
                       "The Ledger", "<polyline", "fixture-model",
                       "News from the Megastructure", "spend: $1.25",
                       "RESEARCH-BEAT-" + DAY, "raw md"):
            self.assertIn(needle, page)
        self.assertNotIn("Fourth sentence", page)  # 3-sentence cap
        self.assertIn("$1.35", page)   # 0.30*2 + 0.75 hourly spend
        self.assertIn("7,000", page)   # 1000*2 + 5000 tokens in
        self.assertIn("2", page)       # research beats count
        # lead pick: the day's first CRITICAL gets the drop-cap slot
        self.assertIn("Fixture routerOS", page)
        self.assertIn("Leads the deck", page)
        # index: newest first, date files only
        with Fixture() as fx:
            idx = dh.digest_index(str(fx.tmp / "digest"))
        self.assertEqual([r["date"] for r in idx], [DAY])


class NewspaperTest(unittest.TestCase):
    """Operator feedback 2026-09-12: columns, summaries, comic strip,
    machine-hall ASCII, quip budget, unchanged contrast tokens."""

    def _render(self, fx):
        dh.DIGESTS = str(fx.tmp / "digest")
        dh.TELEMETRY = str(fx.tmp / "telemetry.db")
        dh.MEDIA = str(fx.tmp / "docs" / "media")
        return dh.render_page(str(fx.tmp / "digest" / (DAY + ".md")),
                              dh.DIGESTS, dh.TELEMETRY)

    def test_columns_css(self):
        # operator directive 2026-09-12: printed-newspaper front page,
        # minimum three columns for the Deck A flow
        self.assertIn("column-count:3", dh.STYLE)
        self.assertIn("@media(max-width:1279px){.cols{column-count:2}}",
                      dh.STYLE)
        self.assertIn("@media(max-width:799px){.cols{column-count:1}}",
                      dh.STYLE)
        self.assertIn("column-rule", dh.STYLE)
        # contrast tokens unchanged (register law)
        self.assertIn("--bg:#0d1117", dh.STYLE)
        self.assertIn("--ink:#e6edf3", dh.STYLE)

    def test_story_summaries(self):
        with Fixture() as fx:
            page = self._render(fx)
        # every Deck A story carries a summary element
        deck_a = page.split("Deck A")[1].split("Deck B")[0]
        self.assertEqual(deck_a.count('<span class="sum">'),
                         deck_a.count('class="item'))

    def test_comic_strip_when_media_exists(self):
        with Fixture() as fx:
            panel = fx.tmp / "docs" / "media" / "manga" / "sample-panel.png"
            panel.parent.mkdir(parents=True)
            panel.write_bytes(b"\x89PNG\r\n\x1a\nfixture")
            page = self._render(fx)
            self.assertIn('src="/hngh-docs/media/manga/sample-panel.png"',
                          page)
            # fail closed: no media -> no comic figure, no dead link
            panel.unlink()
            page = self._render(fx)
        self.assertNotIn("hngh-docs/media", page)

    def test_machine_hall_ascii(self):
        with Fixture() as fx:
            page = self._render(fx)
        self.assertIn("machinehall", page)
        hall = page.split('class="machinehall"')[1].split("</pre>")[0]
        self.assertIn("#", hall)  # the 03h and 09h spend buckets render

    def test_quip_budget(self):
        with Fixture() as fx:
            page = self._render(fx)
        # max one quip per section; the page has at most 5 quip slots
        self.assertLessEqual(page.count('class="quip"'), 5)
        # quips are evidence-first: numbers ride inside the caption
        quip = page.split('class="quip"')[1]
        self.assertRegex(quip, r"\d")


class PublicEditionTest(unittest.TestCase):
    """digest-public.py: ledger first, summaries, comic link, quips."""

    def setUp(self):
        self.dp = _load("digest_public", "jobs/digest-public.py")
        self.repo = Path(tempfile.mkdtemp())
        auto = self.repo / "automation"
        (auto / "digest").mkdir(parents=True)
        (auto / "digest" / (DAY + ".md")).write_text(FIXTURE_DIGEST)
        (auto / "dashboard").mkdir()
        conn = sqlite3.connect(auto / "dashboard" / "telemetry.db")
        conn.execute(
            "CREATE TABLE events(ts TEXT, source TEXT, kind TEXT,"
            " identity TEXT, lane TEXT, unit TEXT, model TEXT,"
            " tokens_in INTEGER, tokens_out INTEGER, cost_usd REAL,"
            " wall_s REAL, subject TEXT, refs TEXT, body TEXT)")
        conn.executemany(
            "INSERT INTO events(ts, kind, tokens_in, cost_usd) VALUES(?,?,?,?)",
            [("2026-09-11T03:00:00Z", "model", 1000, 0.30),
             ("2026-09-11T09:00:00Z", "model", 5000, 0.75)])
        conn.commit()
        conn.close()
        # hermetic seams: render_page reads these env names, same as
        # jobs/digest-local.py — never the operator's real ~/.hngh archive
        os.environ["HNGH_DIGESTS_DIR"] = str(auto / "digest")
        os.environ["HNGH_TELEMETRY_DB"] = str(auto / "dashboard" / "telemetry.db")

    def tearDown(self):
        import shutil
        os.environ.pop("HNGH_DIGESTS_DIR", None)
        os.environ.pop("HNGH_TELEMETRY_DB", None)
        shutil.rmtree(self.repo, ignore_errors=True)

    def test_layout_contract(self):
        media = self.repo / "docs" / "media" / "manga"
        media.mkdir(parents=True)
        (media / "sample-panel.png").write_bytes(b"\x89PNG")
        text = self.dp.render_page(DAY, str(self.repo))
        text.encode("ascii")
        # ledger band stays first, before prose decks
        self.assertLess(text.index("## THE LEDGER"), text.index("## Deck A"))
        # every Deck A story carries a summary line
        deck_a = text.split("## Deck A")[1].split("## Deck B")[0]
        self.assertEqual(deck_a.count("\n  _"), deck_a.count("\n- **"))
        # committed media linked relatively (GitHub renders it)
        self.assertIn("(../media/manga/sample-panel.png)", text)
        # machine hall text-graphic present
        self.assertIn("machine hall", text.lower())
        # quip budget: at most one blockquote caption per section
        self.assertLessEqual(text.count("\n> "), 5)


class ServerRouteTest(unittest.TestCase):
    """/digest-html/ routes over a real bound server, seamed DIGESTS."""

    def setUp(self):
        self.fx = Fixture()
        self.fx.__enter__()
        ds.DIGESTS = str(self.fx.tmp / "digest")
        ds.digest_html.TELEMETRY = str(self.fx.tmp / "telemetry.db")
        ds.Handler.protocol_version = "HTTP/1.1"
        self.httpd = ds.ThreadingHTTPServer(("127.0.0.1", 0), ds.Handler)
        threading.Thread(target=self.httpd.serve_forever,
                         daemon=True).start()
        self.port = self.httpd.server_address[1]

    def tearDown(self):
        self.httpd.shutdown()
        self.httpd.server_close()
        self.fx.__exit__()

    def _get(self, path):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        conn.request("GET", path)
        resp = conn.getresponse()
        body = resp.read()
        conn.close()
        return resp.status, body

    def test_digest_html_200(self):
        status, body = self._get("/digest-html/%s.html" % DAY)
        self.assertEqual(status, 200)
        self.assertIn(b"The Machine Hall", body)
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        conn.request("GET", "/digest-html/%s.html" % DAY)
        self.assertIn("text/html",
                      conn.getresponse().getheader("Content-Type"))
        conn.close()

    def test_index_json(self):
        status, body = self._get("/digest-html/index.json")
        self.assertEqual(status, 200)
        rows = json.loads(body)
        self.assertEqual([r["date"] for r in rows], [DAY])
        self.assertIn("mtime", rows[0])

    def test_fail_closed(self):
        # unknown date -> 404
        self.assertEqual(self._get("/digest-html/1999-01-01.html")[0], 404)
        # traversal via URL-encoded .. -> 404 (jail holds)
        self.assertEqual(
            self._get("/digest-html/..%2f..%2ftelemetry.db.html")[0], 404)
        self.assertEqual(self._get("/digest-html/../etc.html")[0], 404)
        # non-html suffix under the route -> 404
        self.assertEqual(self._get("/digest-html/%s.md" % DAY)[0], 404)
        # garbage name -> 404
        self.assertEqual(self._get("/digest-html/<script>.html")[0], 404)

    def test_media_jail(self):
        media = self.fx.tmp / "docs" / "media" / "manga"
        media.mkdir(parents=True)
        (media / "sample-panel.png").write_bytes(b"\x89PNG\r\n\x1a\n")
        ds.MEDIA_DOCS = str(self.fx.tmp / "docs" / "media")
        status, body = self._get("/hngh-docs/media/manga/sample-panel.png")
        self.assertEqual(status, 200)
        self.assertEqual(
            self._get("/hngh-docs/media/manga/sample-panel.png")[0], 200)
        # traversal, wrong suffix, and missing files all fail closed
        self.assertEqual(
            self._get("/hngh-docs/media/..%2f..%2ftelemetry.db")[0], 404)
        self.assertEqual(
            self._get("/hngh-docs/media/manga/sample-panel.md")[0], 404)
        self.assertEqual(
            self._get("/hngh-docs/media/manga/nope.png")[0], 404)


class BuilderTest(unittest.TestCase):
    """digest-ledger.py: grounded block cites feeds, numbers match."""

    def test_build_block_scrubs_path_tokens(self):
        # digest seam audit 2026-09-16: STATE.md alert crumbs and
        # operator-item text ride the mega line through _ascii() only,
        # so a pathy row echoes /home/... /tmp/... ~/... into deck B
        # (and onward into the public edition). The ledger must land
        # them redacted (fail-closed marker), never dropped.
        with Fixture() as fx:
            (fx.tmp / "STATE.md").write_text(
                "%sT00:30:00Z | 23-bctx-canary.sh | alert | drift in "
                "~/Projects/etc/hngh/STATE.md line 9\n" % DAY)
            (fx.tmp / "dashboard" / "operator-items.json").write_text(
                json.dumps({"generated_at": "", "items": [
                    {"id": "bb",
                     "text": "check /tmp/vr-123/out.log and ~/notes.md now",
                     "status": "open",
                     "first_seen": DAY + "T02:00:00Z", "last_seen": ""}]}))
            block = dl.build(DAY, {
                "spend": (2, 1.25, 3000, 400),
                "sessions": [["%sT01:00:00Z" % DAY, "overnight|fixture-plan",
                              "session-run"]],
                "plans": ([{"slug": "fixture-a", "status": "executed",
                            "accepted": DAY + "T10:00:00Z"}],
                          [{"slug": "fixture-a",
                            "accepted": DAY + "T10:00:00Z"}], [], "queue-a"),
                "operator_items": dl.operator_items(
                    str(fx.tmp / "dashboard" / "operator-items.json")),
                "research_lines": {"planned": 1, "reviewed": 1},
                "posture": dl.posture(DAY, str(fx.tmp / "STATE.md")),
            })
        text = "\n".join(block)
        for token in ("/home/", "/tmp/", "~/"):
            self.assertNotIn(token, text)
        # one marker per path token (2 in the item text, 1 in the crumb)
        self.assertEqual(text.count("[redacted path]"), 3)
        # redaction replaces tokens; rows are kept, never dropped
        self.assertIn("1 open of 1", text)
        self.assertIn("1 alert crumbs today", text)
        # regex-gap extension (2026-09-16 audit follow-up): same seam
        # rules as news-articles.py — bare /home //tmp die, URLs stay
        # untouched (no marker sprayed into them)
        self.assertNotIn("/home", dl.scrub_paths("cd /home alone"))
        self.assertNotIn("/tmp", dl.scrub_paths("wrote /tmp then left"))
        url_text = ("fetched https://example.com/x~/s and "
                    "https://example.com/~user/p today")
        self.assertEqual(dl.scrub_paths(url_text), url_text)

    def test_build_block(self):
        with Fixture() as fx:
            tmp = str(fx.tmp)
            feeds = {
                "spend": (2, 1.25, 3000, 400),
                "sessions": dl.sessions(DAY, str(fx.tmp / "logs" / "budget.md")),
                "plans": dl.plans(DAY,
                                  str(fx.tmp / "dashboard" / "plans.json")),
                "operator_items": dl.operator_items(
                    str(fx.tmp / "dashboard" / "operator-items.json")),
                "research_lines": dl.research_lines(
                    str(fx.tmp / "research-lines.tsv")),
                "posture": dl.posture(DAY, str(fx.tmp / "STATE.md")),
            }
            block = dl.build(DAY, feeds)
        text = "\n".join(block)
        self.assertIn("feeds: dashboard/telemetry.db", text)
        self.assertIn("$1.25", text)
        self.assertIn("sessions: 2 launched", text)
        self.assertIn("queue next: fixture-queue", text)
        self.assertIn("1 open of 1", text)
        self.assertIn("planned 1, reviewed 1", text)
        self.assertIn("1 alert crumbs today", text)
        self.assertIn("fixture-drift", text)


class RenderLayerScrubTest(unittest.TestCase):
    """llc-gate-render-layer-scrub: the ledger's build-time scrub is
    necessary but not sufficient — a below-ledger writer (patrol.py
    morning rounds, or any future direct writer) appends pathy lines
    straight into archive/digest/<date>.md, and three downstream
    renderers read that file verbatim. The render seam is the last
    guard: the newspaper page (the /digest-html/ LAN route serves it),
    the operator email HTML part, and the public edition must all carry
    zero host-path tokens for any digest content, however it got
    written. Red-first: written against the unscrubbed renderers and
    proven failing before the seam landed."""

    def _pathy_digest_file(self, fx):
        """Overwrite the fixture digest with the below-ledger pathy
        variant; returns its path."""
        digest = fx.tmp / "digest" / (DAY + ".md")
        digest.write_text(
            _pathy_digest((fx.tmp / "digest" / (DAY + ".md"))
                          .read_text()))
        return str(digest)

    def test_render_page_scrubs(self):
        # newspaper renderer: deck B, the rounds table, and sidenotes
        # all read the raw digest file
        with Fixture() as fx:
            dh.DIGESTS = str(fx.tmp / "digest")
            dh.TELEMETRY = str(fx.tmp / "telemetry.db")
            page = dh.render_page(self._pathy_digest_file(fx),
                                  dh.DIGESTS, dh.TELEMETRY)
        # content region only: Deck A plate onward (chrome literals in
        # the masthead/ledger plates are renderer constants)
        assert_no_path_tokens(self, page.split("Deck A", 1)[1])

    def test_render_page_scrubs_sidecar_excerpt(self):
        # beat side-notes read RESEARCH-BEAT sidecars, not the daily
        # digest — a model-written sidecar is equally below-ledger text
        with Fixture() as fx:
            dh.DIGESTS = str(fx.tmp / "digest")
            dh.TELEMETRY = str(fx.tmp / "telemetry.db")
            (fx.tmp / "digest" / ("RESEARCH-BEAT-" + DAY
                                  + "-ctx-leak.md")).write_text(
                "# beat\n\nThe probe log is /tmp/beat-probe/state.db. "
                "Second sentence grounds it. Third sentence.\n")
            page = dh.render_page(
                str(fx.tmp / "digest" / (DAY + ".md")),
                dh.DIGESTS, dh.TELEMETRY)
        self.assertNotIn("/tmp/beat-probe", page)
        self.assertIn("[redacted path]", page)

    def test_email_html_scrubs(self):
        # the operator email HTML part embeds deck B and the day's
        # sections verbatim from the same digest file. All lanes are
        # seamed: digest file via HNGH_AUTOMATION_ROOT (set BEFORE the
        # module loads — AUTOMATION is computed at import), telemetry
        # text via HNGH_DIGEST_TELEMETRY, alerts/store/token/plans via
        # their env seams — the only free text below-ledger is the
        # pathy digest fixture.
        with Fixture() as fx:
            fx.tmp.joinpath("automation").mkdir()
            self._pathy_digest_file(fx)
            import shutil
            shutil.move(str(fx.tmp / "digest"),
                        str(fx.tmp / "automation" / "digest"))
            # the fixture mirrors the deployed automation layout: the
            # email renderer loads scrub_paths from
            # <AUTOMATION>/jobs/digest-ledger.py, so the real module
            # file is staged (no second regex anywhere)
            (fx.tmp / "automation" / "jobs").mkdir()
            shutil.copy(str(ROOT / "jobs" / "digest-ledger.py"),
                        str(fx.tmp / "automation" / "jobs"
                            / "digest-ledger.py"))
            env = {
                "HNGH_AUTOMATION_ROOT": str(fx.tmp / "automation"),
                "HNGH_DIGEST_TELEMETRY": "spend: fixture $1.25 today",
                "HNGH_DIGEST_ALERTS": "none — quiet window",
                "HNGH_DIGEST_PLANS": str(fx.tmp / "missing-plans.json"),
                "HNGH_DIGEST_QUEUE": "queue: fixture-queue",
                "HNGH_DASHBOARD_TOKEN": "",
                "HNGH_DIGEST_STORE_DIR": str(fx.tmp / "store"),
                # an existing FILE: keeps the dormant-email setup lane
                # quiet (that lane embeds AUTOMATION by design)
                "HNGH_NOTIFY_EMAIL_CONF": str(
                    fx.tmp / "automation" / "digest" / (DAY + ".md")),
            }
            saved = {k: os.environ.get(k) for k in env}
            os.environ.update(env)
            try:
                hd = _load("html_digest", "scripts/html-digest.py")
                html_part = hd.render_html(_fixture_g())
            finally:
                for k, v in saved.items():
                    if v is None:
                        os.environ.pop(k, None)
                    else:
                        os.environ[k] = v
        assert_no_path_tokens(self, html_part)

    def test_public_edition_scrubs(self):
        # the pushable public edition renders the same parse
        dp = _load("digest_public2", "jobs/digest-public.py")
        with Fixture() as fx:
            repo = Path(tempfile.mkdtemp())
            try:
                self._pathy_digest_file(fx)
                os.environ["HNGH_DIGESTS_DIR"] = str(fx.tmp / "digest")
                os.environ["HNGH_TELEMETRY_DB"] = str(
                    fx.tmp / "telemetry.db")
                text = dp.render_page(DAY, str(repo))
            finally:
                os.environ.pop("HNGH_DIGESTS_DIR", None)
                os.environ.pop("HNGH_TELEMETRY_DB", None)
                import shutil
                shutil.rmtree(repo, ignore_errors=True)
        # content region: Deck A heading through the reading room
        # (the ledger band and reading room cite ~/.hngh/ paths as
        # machine chrome)
        assert_no_path_tokens(
            self,
            text.split("## Deck A", 1)[1].split("## Reading room")[0])

    def setUp(self):
        """A bound server + a pathy fixture digest (below-ledger text),
        mirroring ServerRouteTest's seams so the leak assertion runs
        against the real HTTP payload the LAN serves."""
        self.fx = Fixture()
        self.fx.__enter__()
        ds.DIGESTS = str(self.fx.tmp / "digest")
        ds.digest_html.TELEMETRY = str(self.fx.tmp / "telemetry.db")
        self._pathy_digest_file(self.fx)
        ds.Handler.protocol_version = "HTTP/1.1"
        self.httpd = ds.ThreadingHTTPServer(("127.0.0.1", 0), ds.Handler)
        threading.Thread(target=self.httpd.serve_forever,
                         daemon=True).start()
        self.port = self.httpd.server_address[1]

    def tearDown(self):
        self.httpd.shutdown()
        self.httpd.server_close()
        self.fx.__exit__()

    def _get(self, path):
        conn = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        conn.request("GET", path)
        resp = conn.getresponse()
        body = resp.read()
        conn.close()
        return resp.status, body

    def test_digest_html_route_scrubs(self):
        # the LAN-reachable route must fail closed on the same fixture:
        # 200 + rendered page, zero path tokens in the payload
        status, body = self._get("/digest-html/%s.html" % DAY)
        self.assertEqual(status, 200)
        # content region only (renderer chrome literals out of scope)
        assert_no_path_tokens(
            self, body.decode("ascii", "replace").split("Deck A", 1)[1])


def _fixture_g():
    """Minimal gather-shaped dict for html-digest.render_html (the
    email renderer needs only what the decks read; everything else
    renders as quiet placeholders)."""
    return {
        "day": DAY,
        "tel": {"spend": "1.25", "calls": "2", "tokens": "3000"},
        "alerts24": [], "prog": "all plans executed/rejected",
        "delta": 0, "pending": [], "spend_t": "1.25", "spend_y": "0.75",
        "klines": [], "alines": [], "fresh": [], "untracked": [],
        "have_prev": False, "lessons": "none", "night": "",
        "bench": "",
    }


if __name__ == "__main__":
    unittest.main(verbosity=2)
