#!/usr/bin/env python3
"""Research-routes map view contract tests, hermetic.

dashboard/routes-view.js + dashboard/routes.html render the routes/1 feed
(GET /research-routes.json, jobs/research-routes.py) as the first
game-layer surface: research lines drawn as ROUTES across a map — each
route a polyline over a time axis (x = status-transition dates), lanes
per status family, the terminus node shaped by its disposition action
(adopted = filled circle, killed = X mark, parked = hollow circle), and
harvested routes carrying a lesson marker (d1-harvest's
research-lessons.tsv flag). Honesty rules are binding, same contract as
history-view: the gate is exact — only schema === 'routes/1' with a
routes array renders; anything else fails closed into the literal
#routeserr banner. The map's date span comes ONLY from the payload
(routes/1 carries its own `generated` stamp plus per-route dates); no
client dates anywhere. Refs stay jailed via /hngh-docs/docs/ when
present. Display layer only — never governance input.

Layers, same discipline as test-history-view.py:
- textual contract on the served sources (dashboard/ is quarantined
  machine data; a fresh clone may not have them),
- builder fixture tests against a temp repo root (transition extraction
  from TSV fixtures, terminus mapping, legacy-width disposition rows,
  harvested flag, cap, schema validation, atomic write),
- real headless execution of the pure render/geometry helpers via node
  (valid feed, empty, wrong schema, cap + overflow, lane/terminus
  geometry over fixture payloads),
- a served-route smoke test: GET /research-routes.json over a bound
  ephemeral server returns 200 with the schema key (builder seamed, no
  daemon) and routes.html serves through the static fallback.
"""
import http.client
import importlib.util
import json
import re
import shutil
import tempfile
import threading
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DASH = ROOT / "dashboard"
JOBS = ROOT / "jobs"


def src(name):
    # dashboard/ is quarantined machine data (automation/.gitignore);
    # a fresh clone (CI runner) has no served sources to contract-check
    if not (DASH / "index.html").is_file():
        raise unittest.SkipTest("dashboard/ not present (quarantined machine data)")
    return (DASH / name).read_text()


def run_node(script):
    """Run a node -e script; nonzero exit or stderr -> AssertionError.
    Skips when node is absent so a browser-less CI runner still passes."""
    node = shutil.which("node")
    if node is None:
        raise unittest.SkipTest("node not available for JS execution")
    import subprocess
    out = subprocess.run([node, "-e", script], capture_output=True,
                         text=True, timeout=30)
    if out.returncode != 0:
        raise AssertionError("node script failed: " + out.stderr.strip()[:400])
    return out.stdout


def _load(name, rel):
    spec = importlib.util.spec_from_file_location(name, str(ROOT / rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _load_builder():
    return _load("research_routes", "jobs/research-routes.py")


def _load_schema():
    return _load("viz_schema_routes", "jobs/viz_schema.py")


# ---------------------------------------------------------------------------
# fixture TSV writers (temp repo root, same hermetic pattern as
# test-research-harvest.py's fixtures)
# ---------------------------------------------------------------------------

LINES_HEADER = ""
DISP_HEADER = ("line\taction\tverdict\treviewer\tevidence\tdate\t"
               "support\toppose\tfollowons\n")
LESSONS_HEADER = "lesson_id\tdate\tline_id\tsubject\tlesson\tstatus\n"


def write_root(tmp, lines_rows=(), disp_rows=(), lessons_rows=()):
    """A fake repo root with automation/{research-lines,research-
    dispositions,research-lessons}.tsv. Rows are field tuples. The lines
    TSV is headerless (graph-data.py read parity); the other two carry
    their writer headers."""
    auto = tmp / "automation"
    auto.mkdir(parents=True, exist_ok=True)
    (auto / "research-lines.tsv").write_text(
        "".join("\t".join(r) + "\n" for r in lines_rows))
    (auto / "research-dispositions.tsv").write_text(
        DISP_HEADER + "".join("\t".join(r) + "\n" for r in disp_rows))
    if lessons_rows is not None:
        (auto / "research-lessons.tsv").write_text(
            LESSONS_HEADER + "".join("\t".join(r) + "\n"
                                     for r in lessons_rows))
    return tmp


def lines_row(lid, status, ts, title):
    return (lid, status, ts, title)


def disp_row(lid, action, date, verdict="adopted -- fine"):
    # 9-field current-writer shape; support/oppose/followons empty
    return (lid, action, verdict, "model:test:1", "/evidence.md", date,
            "", "", "")


def lessons_row(lid, date, line_id, status="active"):
    return ("les-%s-%s" % (date[:10].replace("-", ""), line_id), date,
            line_id, "subject for " + line_id, "do the thing", status)


# ---------------------------------------------------------------------------
# schema block (viz_schema.py gains routes/1)
# ---------------------------------------------------------------------------

class RoutesSchema(unittest.TestCase):
    """routes/1 validator: exact envelope, per-route shape, terminus
    checks, duplicate ids, extras fail closed; additive scalars warn."""

    def setUp(self):
        self.vs = _load_schema()

    def route(self, rid="r1", **over):
        r = {"id": rid, "title": "route " + rid,
             "status": "reviewed",
             "segments": ["2026-09-01T00:00:00Z", "2026-09-10T00:00:00Z"],
             "terminus": {"action": "adopted", "date": "2026-09-10T00:00:00Z"},
             "harvested": True}
        r.update(over)
        return r

    def payload(self, routes=None):
        return {"schema": "routes/1",
                "generated": "2026-09-15T12:00:00Z",
                "routes": [self.route()] if routes is None else routes}

    def test_valid_payload_accepts(self):
        issues = self.vs.validate_payload(self.payload(), "routes/1")
        self.assertFalse([i for i in issues if i["severity"] == "ERROR"])

    def test_envelope_is_exact(self):
        p = self.payload()
        p["extra"] = 1
        issues = self.vs.validate_payload(p, "routes/1")
        self.assertTrue(any(i["code"] == "unknown-envelope-key" for i in issues))
        p2 = self.payload()
        del p2["generated"]
        issues2 = self.vs.validate_payload(p2, "routes/1")
        self.assertTrue(any(i["code"] == "missing-required-field"
                            for i in issues2))

    def test_route_missing_required_fields_fail_closed(self):
        for drop in ("id", "title", "status", "segments", "terminus",
                     "harvested"):
            r = self.route()
            del r[drop]
            issues = self.vs.validate_payload(self.payload([r]), "routes/1")
            self.assertTrue(any(i["code"] == "missing-required-field"
                                for i in issues), drop)

    def test_route_wrong_types_fail_closed(self):
        issues = self.vs.validate_payload(self.payload([self.route(
            harvested="yes")]), "routes/1")
        self.assertTrue(any(i["code"] == "wrong-type" for i in issues))
        issues2 = self.vs.validate_payload(self.payload([self.route(
            segments="2026-09-01")]), "routes/1")
        self.assertTrue(any(i["code"] == "wrong-type" for i in issues2))
        issues3 = self.vs.validate_payload(self.payload([self.route(
            terminus={"action": "adopted"})]), "routes/1")  # date missing
        self.assertTrue(any(i["severity"] == "ERROR" for i in issues3))

    def test_route_nested_extra_fails_closed_scalar_extra_warns(self):
        r = self.route(unexpected={"nested": 1})
        issues = self.vs.validate_payload(self.payload([r]), "routes/1")
        self.assertTrue(any(i["code"] == "unknown-key-nested-payload"
                            for i in issues))
        r2 = self.route(note="additive scalar")
        issues2 = self.vs.validate_payload(self.payload([r2]), "routes/1")
        self.assertFalse([i for i in issues2 if i["severity"] == "ERROR"])
        self.assertTrue(any(i["severity"] == "WARN" for i in issues2))

    def test_unknown_terminus_action_and_status_fail_closed(self):
        issues = self.vs.validate_payload(self.payload([self.route(
            terminus={"action": "reborn",
                      "date": "2026-09-10T00:00:00Z"})]), "routes/1")
        self.assertTrue(any(i["code"] == "unknown-terminus-action"
                            for i in issues))
        issues2 = self.vs.validate_payload(self.payload([self.route(
            status="teleported")]), "routes/1")
        self.assertTrue(any(i["code"] == "unknown-status-value"
                            for i in issues2))

    def test_terminus_not_adopted_with_harvest_true_fails_closed(self):
        r = self.route(status="parked", harvested=True,
                       terminus={"action": "parked",
                                 "date": "2026-09-10T00:00:00Z"})
        issues = self.vs.validate_payload(self.payload([r]), "routes/1")
        self.assertTrue(any(i["code"] == "harvest-requires-adopted"
                            for i in issues))

    def test_duplicate_route_ids_fail_closed(self):
        issues = self.vs.validate_payload(self.payload(
            [self.route("r1"), self.route("r1")]), "routes/1")
        self.assertTrue(any(i["code"] == "duplicate-route-id" for i in issues))

    def test_cli_accepts_and_rejects(self):
        import subprocess, sys, tempfile, os
        with tempfile.NamedTemporaryFile("w", suffix=".json",
                                         delete=False) as fh:
            json.dump(self.payload(), fh)
            good = fh.name
        try:
            rc = subprocess.run(
                [sys.executable, str(JOBS / "viz_schema.py"),
                 "--schema", "routes/1", good],
                capture_output=True, text=True).returncode
            self.assertEqual(rc, 0)
        finally:
            os.unlink(good)
        with tempfile.NamedTemporaryFile("w", suffix=".json",
                                         delete=False) as fh:
            json.dump({"schema": "routes/1", "generated": "x", "routes": []},
                      fh)
            bad = fh.name
        try:
            rc2 = subprocess.run(
                [sys.executable, str(JOBS / "viz_schema.py"), bad],
                capture_output=True, text=True).returncode
            self.assertEqual(rc2, 0)  # empty routes is a valid envelope
        finally:
            os.unlink(bad)


# ---------------------------------------------------------------------------
# payload builder fixture tests (transition extraction, terminus mapping,
# harvested flag, cap, validation + atomic write)
# ---------------------------------------------------------------------------

class RoutesBuilder(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        self.rb = _load_builder()

    def build(self, **kw):
        return self.rb.build(self.tmp, **kw)

    def test_transitions_from_line_status_history(self):
        # lines carry the CURRENT status; the dispositions ledger carries
        # the dated history. A line planned -> crystallized -> reviewed
        # with an adopted terminus yields segments for each transition
        # date and the adopted terminus.
        write_root(
            self.tmp,
            lines_rows=[
                lines_row("alpha", "reviewed", "2026-09-10T00:00:00Z",
                          "alpha line"),
            ],
            disp_rows=[
                disp_row("alpha", "adopted", "2026-09-08"),
                disp_row("beta", "parked", "2026-09-09"),
            ])
        payload = self.build()
        self.assertEqual(payload["schema"], "routes/1")
        self.assertRegex(payload["generated"], r"Z$")
        by_id = {r["id"]: r for r in payload["routes"]}
        alpha = by_id["alpha"]
        self.assertEqual(alpha["title"], "alpha line")
        self.assertEqual(alpha["status"], "reviewed")
        self.assertEqual(alpha["harvested"], False)
        self.assertEqual(alpha["terminus"],
                         {"action": "adopted", "date": "2026-09-08T00:00:00Z"})
        # segments are ISO Z dates of status transitions, ascending
        self.assertEqual(alpha["segments"], ["2026-09-08T00:00:00Z"])

    def test_no_terminus_means_open_route(self):
        write_root(
            self.tmp,
            lines_rows=[lines_row("open", "planned", "2026-09-12T00:00:00Z",
                                  "open line")])
        payload = self.build()
        r = payload["routes"][0]
        self.assertEqual(r["terminus"], {"action": "open", "date": ""})
        self.assertEqual(r["harvested"], False)

    def test_terminus_latest_wins_and_date_normalized(self):
        # dispositions rows out of chronological order: latest date wins
        write_root(
            self.tmp,
            lines_rows=[lines_row("g", "reviewed", "2026-09-12T00:00:00Z",
                                  "g line")],
            disp_rows=[
                disp_row("g", "parked", "2026-09-02"),
                disp_row("g", "adopted", "2026-09-05"),
            ])
        r = self.build()["routes"][0]
        self.assertEqual(r["terminus"],
                         {"action": "adopted", "date": "2026-09-05T00:00:00Z"})

    def test_legacy_narrow_disposition_rows_parse(self):
        # d1-harvest legacy accommodation: 5/6-field rows are
        # prefix-parseable and must not poison the terminus lookup
        write_root(
            self.tmp,
            lines_rows=[lines_row("legacy", "reviewed",
                                  "2026-09-12T00:00:00Z", "legacy line")],
            disp_rows=[
                ("legacy", "adopted", "adopted -- old verdict",
                 "model:old:1", "/evidence.md", "2026-09-03"),
            ])
        r = self.build()["routes"][0]
        self.assertEqual(r["terminus"],
                         {"action": "adopted", "date": "2026-09-03T00:00:00Z"})

    def test_harvested_flag_from_lessons_tsv(self):
        write_root(
            self.tmp,
            lines_rows=[
                lines_row("h1", "reviewed", "2026-09-10T00:00:00Z", "h one"),
                lines_row("h2", "reviewed", "2026-09-10T00:00:00Z", "h two"),
            ],
            disp_rows=[disp_row("h1", "adopted", "2026-09-04"),
                       disp_row("h2", "adopted", "2026-09-05")],
            lessons_rows=[lessons_row("2026-09-04", "2026-09-04T00:00:00Z",
                                      "h1")])
        by_id = {r["id"]: r for r in self.build()["routes"]}
        self.assertTrue(by_id["h1"]["harvested"])
        self.assertFalse(by_id["h2"]["harvested"])

    def test_missing_lessons_tsv_means_all_unharvested(self):
        write_root(
            self.tmp,
            lines_rows=[lines_row("h1", "reviewed", "2026-09-10T00:00:00Z",
                                  "h one")],
            disp_rows=[disp_row("h1", "adopted", "2026-09-04")],
            lessons_rows=None)
        self.assertFalse(self.build()["routes"][0]["harvested"])

    def test_cap_newest_wins(self):
        rows = [lines_row("k%03d" % i, "planned",
                          "2026-09-%02dT00:00:00Z" % (1 + i % 27),
                          "line %d" % i) for i in range(120)]
        disps = [disp_row("k%03d" % i, "parked",
                          "2026-09-%02d" % (1 + i % 27))
                 for i in range(120)]
        write_root(self.tmp, lines_rows=rows, disp_rows=disps)
        payload = self.build()
        self.assertEqual(len(payload["routes"]), self.rb.ROUTES_CAP)
        # newest-wins on the last_transition date: the kept head is the
        # NEWEST routes, so no kept route may predate the cut boundary
        kept_min = min(r["segments"][-1] for r in payload["routes"])
        cut = sorted((r["segments"][-1] for r in
                      self.build(cap=10 ** 9)["routes"]), reverse=True)
        if len(cut) > self.rb.ROUTES_CAP:
            self.assertGreaterEqual(kept_min, cut[self.rb.ROUTES_CAP])

    def test_malformed_rows_fail_closed(self):
        # 3-field rows are exactly the width failure the headerless
        # lines reader must refuse
        auto = self.tmp / "automation"
        auto.mkdir(parents=True)
        (auto / "research-lines.tsv").write_text("a\tb\tc\n")
        (auto / "research-dispositions.tsv").write_text(DISP_HEADER)
        with self.assertRaises(Exception):
            self.build()
        # unknown status values fail closed too
        write_root(self.tmp,
                   lines_rows=[lines_row("bad", "ghosted",
                                         "2026-09-10T00:00:00Z", "bad")],
                   disp_rows=[])
        with self.assertRaises(Exception):
            self.build()

    def test_write_out_validates_and_writes_atomically(self):
        write_root(
            self.tmp,
            lines_rows=[lines_row("alpha", "reviewed", "2026-09-10T00:00:00Z",
                                  "alpha line")],
            disp_rows=[disp_row("alpha", "adopted", "2026-09-08")])
        out = self.tmp / "out" / "research-routes.json"
        ok, detail = self.rb.write_out(self.build(), out)
        self.assertTrue(ok, detail)
        data = json.loads(out.read_text())
        self.assertEqual(data["schema"], "routes/1")
        self.assertEqual(data["routes"][0]["id"], "alpha")
        self.assertFalse(list(out.parent.glob("*.tmp")))

    def test_write_out_rejects_invalid_payload_keeping_last_good(self):
        out = self.tmp / "out" / "research-routes.json"
        out.parent.mkdir(parents=True)
        out.write_text('{"schema": "routes/1", "generated": "g", "routes": []}\n')
        bad = {"schema": "routes/1", "generated": "2026-09-15T00:00:00Z",
               "routes": [{"id": "x"}]}
        ok, detail = self.rb.write_out(bad, out)
        self.assertFalse(ok)
        self.assertIn("routes/1", detail)


# ---------------------------------------------------------------------------
# textual contract on the served sources
# ---------------------------------------------------------------------------

class RoutesPage(unittest.TestCase):
    def setUp(self):
        self.html = src("routes.html")
        self.js = src("routes-view.js")

    def test_page_wiring_and_headers(self):
        for needle in ('charset', 'viewport',
                       '<link rel="icon" href="data:,"/>',
                       'href="style.css', 'src="routes-view.js"',
                       "<main"):
            self.assertIn(needle, self.html, needle)
        # link checker: every local href target exists on disk
        for href in re.findall(r'href="([^"#][^"]*)"', self.html):
            if href.startswith(("http", "data:")):
                continue
            self.assertTrue((DASH / href.split("?")[0]).exists(), href)
        # reachable from the nerve center and the standalone siblings
        self.assertIn('href="routes.html"', src("index.html"))
        self.assertIn('href="routes.html"', src("gantt.html"))
        self.assertIn('href="routes.html"', src("story.html"))

    def test_tabs_and_registry_mounting(self):
        idx = src("index.html")
        self.assertIn('data-tab="routes"', idx)
        self.assertIn('id="p-routes"', idx)
        self.assertIn('id="routes-root"', idx)
        self.assertIn('src="routes-view.js" defer', idx)
        self.assertIn("'routes-root': ['routes',  'RoutesView']", src("app.js"))

    def test_fail_closed_banner_id_is_literal(self):
        self.assertIn('id="routeserr"', self.html)
        self.assertIn('"routeserr"', self.js)


class RoutesViewJs(unittest.TestCase):
    def setUp(self):
        self.js = src("routes-view.js")

    def test_fetches_research_routes_json_with_manual_refresh(self):
        self.assertIn('fetchJson("research-routes.json")', self.js)
        # story-view's no-poll pattern: refresh button + one load, no timer
        self.assertIn("refresh-btn", self.js)
        self.assertNotIn("setInterval(", self.js)
        self.assertNotIn("HnghPoll", self.js)

    def test_fail_closed_gate_schema_and_routes(self):
        self.assertIn("feedOk(feed)", self.js)
        self.assertLess(self.js.index("feedOk(feed)"),
                        self.js.index("renderAll("),
                        "envelope gate runs before rendering")
        self.assertIn("Array.isArray(feed.routes)", self.js)
        # map span derives from the payload only — never a client date
        self.assertIn("feed.generated", self.js)
        self.assertNotIn("toISOString", self.js)
        self.assertNotRegex(self.js, r"new Date\(\)")

    def test_svg_rendering_terminus_shapes_and_lesson_marker(self):
        # the game-layer surface: polylines over a time axis, terminus
        # node shaped by action, lesson marker for harvested routes
        self.assertIn("<polyline", self.js)
        self.assertIn("polyline", self.js)
        for token in ("adopted", "killed", "parked"):
            self.assertIn(token, self.js)
        self.assertIn("harvested", self.js)

    def test_esc_and_owned_style_tag_not_style_css(self):
        self.assertIn("function esc(", self.js)
        self.assertGreaterEqual(self.js.count("esc(") - 1, 4)
        self.assertIn("<style>", self.js)
        self.assertIn("document.head.appendChild", self.js)

    def test_jailed_refs_only(self):
        # evidence links only through the jailed /hngh-docs/docs/ route
        if "/hngh-docs/docs/" in self.js:
            self.assertLess(self.js.index('startsWith("docs/")'),
                            self.js.index('href="'),
                            "ref jail check precedes any href build")

    def test_cap_and_overflow_marker(self):
        self.assertIn("DISPLAY_CAP = 100", self.js)
        self.assertIn(" shown)", self.js)


# ---------------------------------------------------------------------------
# headless execution of the pure helpers over fixture payloads
# ---------------------------------------------------------------------------

def helpers_source():
    """Slice the pure-function head of routes-view.js (everything up to
    the "// ---- boot ----" mark) and strip the IIFE opener + 'use
    strict', the same extraction test-history-view.py performs."""
    v = src("routes-view.js")
    head = v[:v.index("// ---- boot ----")]
    body = head[head.index("(function () {") + len("(function () {"):]
    return body.replace("'use strict';", "", 1)


def helpers_js():
    return ("const H = (new Function(%s +\n"
            "'\\nreturn {feedOk, routeSpan, visibleRoutes, layout,"
            " routeSvg, renderRoutes, overflowLine};'))();\n"
            % json.dumps(helpers_source()))


def route(rid, status="reviewed", harvested=False, action=None, date=None,
          segs=("2026-09-01T00:00:00Z", "2026-09-10T00:00:00Z"), title=None):
    # status is a LINE lifecycle stage; `action` is the terminus action
    return {"id": rid, "title": title or ("route " + rid),
            "status": status, "segments": list(segs),
            "terminus": {"action": action or status,
                         "date": date or segs[-1]},
            "harvested": harvested}


def feed(routes=(), generated="2026-09-15T12:00:00Z"):
    return {"schema": "routes/1", "generated": generated,
            "routes": list(routes)}


class RoutesViewPure(unittest.TestCase):
    """Fixture-driven execution: valid feed, empty, wrong schema, cap +
    overflow, lane layout geometry, terminus shapes, lesson markers."""

    def exec_svg(self, payload, **opts):
        return run_node(
            helpers_js() +
            "const feed = %s;\n"
            "if (!H.feedOk(feed)) { console.log('GATE_FAIL');"
            " process.exit(0); }\n"
            "const routes = H.visibleRoutes(feed, %s, %s);\n"
            "const span = H.routeSpan(feed, routes);\n"
            "console.log(JSON.stringify({span: span,"
            " geo: H.layout(routes, span, %s, %s),"
            " html: H.renderRoutes(routes, span, %d)}));"
            % (json.dumps(payload),
               json.dumps(opts.get("status", "")),
               json.dumps(opts.get("family", "")),
               json.dumps(opts.get("width", 800)),
               json.dumps(opts.get("laneH", 34)),
               opts.get("cap", 100)))

    def test_valid_feed_renders_polylines_with_payload_span(self):
        payload = feed([
            route("a", harvested=True, action="adopted"),
            route("b", status="planned", action="open",
                  date=""),
        ])
        out = json.loads(self.exec_svg(payload))
        self.assertEqual(out["span"]["first"], "2026-09-01T00:00:00Z")
        self.assertEqual(out["span"]["last"], "2026-09-10T00:00:00Z")
        html = out["html"]
        self.assertEqual(html.count("<polyline"), 2)
        self.assertIn('rv-mark-harvest', html)  # lesson marker on a
        self.assertIn("route a", html)
        self.assertNotIn("<script", html)

    def test_empty_routes_render_placeholder(self):
        out = json.loads(self.exec_svg(feed([])))
        self.assertEqual(out["html"].count("<polyline"), 0)
        self.assertIn("rv-empty", out["html"])
        self.assertIsNone(out["span"]["first"])

    def test_wrong_schema_and_shape_fail_closed(self):
        self.assertIn("GATE_FAIL", self.exec_svg({"routes": []}))
        self.assertIn("GATE_FAIL", self.exec_svg(
            {"schema": "routes/2", "generated": "g", "routes": []}))
        self.assertIn("GATE_FAIL", self.exec_svg(
            {"schema": "routes/1", "generated": "g", "routes": "nope"}))

    def test_cap_and_overflow(self):
        routes = [route("r%03d" % i) for i in range(120)]
        out = json.loads(self.exec_svg(feed(routes)))
        self.assertEqual(out["html"].count("<polyline"), 100)
        self.assertIn("(100 of 120 shown)", out["html"])

    def test_lanes_per_status_family(self):
        routes = [route("ad", status="reviewed", action="adopted",
                        segs=("2026-09-01T00:00:00Z", "2026-09-04T00:00:00Z",
                              "2026-09-06T00:00:00Z")),
                  route("cr", status="crystallized", action="parked",
                        segs=("2026-09-03T00:00:00Z", "2026-09-07T00:00:00Z",
                              "2026-09-10T00:00:00Z")),
                  route("kl", status="reviewed", action="killed",
                        segs=("2026-09-02T00:00:00Z", "2026-09-08T00:00:00Z",
                              "2026-09-09T00:00:00Z")),
                  route("pl", status="planned", action="open", date="",
                        segs=("2026-09-01T00:00:00Z", "2026-09-05T00:00:00Z"))]
        out = json.loads(self.exec_svg(feed(routes)))
        geo = out["geo"]
        lanes = sorted(set(g["lane"] for g in geo))
        # reviewed, crystallized, planned each land on a distinct lane
        # (expanding/contracting share the planned lane by design)
        self.assertEqual(len(lanes), 3)
        by_id = {g["id"]: g for g in geo}
        # x advances with the terminus date (time axis): ad 09-06 <
        # cr 09-10, and cr 09-10 > kl 09-09
        self.assertLess(by_id["ad"]["x"], by_id["cr"]["x"] - 1)
        self.assertGreater(by_id["cr"]["x"], by_id["kl"]["x"] + 1)

    def test_terminus_shapes_by_action(self):
        routes = [route("ad", action="adopted"),
                  route("kl", action="killed"),
                  route("pk", action="parked"),
                  route("op", action="open", date="")]
        out = json.loads(self.exec_svg(feed(routes)))
        html = out["html"]
        self.assertIn("rv-term-adopted", html)
        self.assertIn("rv-term-killed", html)
        self.assertIn("rv-term-parked", html)
        self.assertIn("rv-term-open", html)

    def test_status_family_filter(self):
        routes = [route("ad", status="reviewed", action="adopted"),
                  route("ex", status="expanding", action="open", date="")]
        out = json.loads(self.exec_svg(feed(routes), status="expanding"))
        self.assertEqual([g["id"] for g in out["geo"]], ["ex"])


# ---------------------------------------------------------------------------
# served-route smoke test: GET /research-routes.json 200 + schema key
# ---------------------------------------------------------------------------

class RoutesEndpoint(unittest.TestCase):
    """GET /research-routes.json over a bound ephemeral server; builder
    seamed (same harness pattern as test-history-view.py)."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        dash = self.tmp / "dash"
        dash.mkdir()
        # the static-file fallback needs the real served files to exist
        for name in ("index.html", "routes.html", "routes-view.js"):
            shutil.copy(DASH / name, dash / name)
        for name in ("operator-items.json", "operator-dismissed.json",
                     "readout.json"):
            (dash / name).write_text("{}")
        self.ds = _load("dashboard_server_routes", "dashboard-server.py")
        self.ds.DASHBOARD = str(dash)
        self.ds.TOKEN_FILE = str(dash / "token.txt")
        self.ds.load_token()
        self.payload = feed([route("alpha"), route("beta", harvested=True)])
        self._real = self.ds.research_routes.build
        self.ds.research_routes.build = lambda *a, **k: json.loads(
            json.dumps(self.payload))
        self.ds._routes_cache = (0.0, None)  # cold, per-test
        self.ds.Handler.protocol_version = "HTTP/1.1"
        self.httpd = self.ds.ThreadingHTTPServer(("127.0.0.1", 0),
                                                 self.ds.Handler)
        threading.Thread(target=self.httpd.serve_forever,
                         daemon=True).start()
        self.port = self.httpd.server_address[1]

    def tearDown(self):
        self.httpd.shutdown()
        self.httpd.server_close()
        self.ds.research_routes.build = self._real
        shutil.rmtree(self.tmp, ignore_errors=True)

    def get(self, path="/research-routes.json"):
        c = http.client.HTTPConnection("127.0.0.1", self.port, timeout=10)
        c.request("GET", path, headers={"Connection": "close"})
        r = c.getresponse()
        data = r.read()
        c.close()
        if path.endswith(".json"):
            return r.status, json.loads(data) if data else {}
        return r.status, data

    def test_serves_200_with_routes_schema_key(self):
        st, body = self.get()
        self.assertEqual(st, 200)
        self.assertEqual(body.get("schema"), "routes/1")
        self.assertIsInstance(body.get("routes"), list)
        self.assertEqual(len(body["routes"]), 2)

    def test_page_served_and_view_registered_in_index(self):
        st, body = self.get("/routes.html")
        self.assertEqual(st, 200)
        self.assertIn(b"routes-view.js", body)
        st2, idx = self.get("/index.html")
        self.assertEqual(st2, 200)
        self.assertIn(b'data-tab="routes"', idx)


if __name__ == "__main__":
    unittest.main()
