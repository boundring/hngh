#!/usr/bin/env python3
"""History spine view (View A) contract tests, hermetic.

dashboard/history-view.js + dashboard/history.html render the merged
history/1 feed (GET /history.json, jobs/history-feed.py) as a vertical
newest-first stream with source/kind filter chips, a 100-row display cap
with "(N of M shown)", and evidence links only through the jailed
/hngh-docs/docs/ route. Honesty rules are binding: the page's own
generated_at stamp gates rendering (fail closed like story-view's
todayFromStamp), refs render as links ONLY when they are repo-relative
paths, and gitlog rows link their short hash instead. Display layer only
— never governance input.

Three layers, same discipline as test-dashboard-p0.py:
- textual contract on the served sources (dashboard/ is quarantined
  machine data; a fresh clone may not have them),
- real headless execution of the pure render/filter/cap helpers via
  node (fixture history/1 payloads: valid, empty, missing generated_at,
  600 entries -> cap + overflow marker, source filter),
- a served-route smoke test: GET /history.json over a bound ephemeral
  server returns 200 with the schema key (builder seamed, no daemon).
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


def entry(n, source="gitlog", **over):
    # ts desc as n asc: entry(4) is NEWER than entry(1) (the feed is
    # ts desc; fixtures must match the producer's ordering contract)
    e = {"key": "%s:k%04d" % (source, n),
         "ts": "2026-09-%02dT12:00:00Z" % (10 + n % 5),
         "summary": "entry %d from %s" % (n, source),
         "source": source}
    if source == "gitlog":
        e["author"] = "operator"
        e["short"] = "ab%04dcd" % n
    if source == "report":
        e["kind"] = "progress" if n % 2 == 0 else "alert"
        e["ref"] = "docs/project/report-bodies/x-%d.md" % n
    if source == "records":
        e["ref"] = "docs/records/2026-09-01-slug.md"
    return e


def feed(entries=(), generated_at="2026-09-15T12:00:00Z"):
    f = {"schema": "history/1",
         "generated_at": generated_at,
         "entries": list(entries)}
    return f


# ---------------------------------------------------------------------------
# textual contract on the served sources
# ---------------------------------------------------------------------------

class HistoryPage(unittest.TestCase):
    def setUp(self):
        self.html = src("history.html")
        self.js = src("history-view.js")

    def test_page_wiring_and_headers(self):
        for needle in ('charset', 'viewport',
                       '<link rel="icon" href="data:,"/>',
                       'href="style.css', 'src="history-view.js"',
                       "<main"):
            self.assertIn(needle, self.html, needle)
        # link checker: every local href target exists on disk
        for href in re.findall(r'href="([^"#][^"]*)"', self.html):
            if href.startswith(("http", "data:")):
                continue
            self.assertTrue((DASH / href.split("?")[0]).exists(), href)
        # reachable from the nerve center and the standalone siblings
        self.assertIn('href="history.html"', src("index.html"))
        self.assertIn('href="history.html"', src("gantt.html"))
        self.assertIn('href="history.html"', src("story.html"))

    def test_tabs_and_registry_mounting(self):
        idx = src("index.html")
        self.assertIn('data-tab="history"', idx)
        self.assertIn('id="p-history"', idx)
        self.assertIn('id="history-root"', idx)
        self.assertIn('src="history-view.js" defer', idx)
        self.assertIn("'history-root': ['history',  'HistoryView']", src("app.js"))

    def test_fail_closed_banner_id_is_literal(self):
        # kept literal for this contract test, like story-view's storyerr
        self.assertIn('id="histerr"', self.html)
        self.assertIn('"histerr"', self.js)


class HistoryViewJs(unittest.TestCase):
    def setUp(self):
        self.js = src("history-view.js")

    def test_fetches_history_json_with_manual_refresh(self):
        self.assertIn('fetchJson("history.json")', self.js)
        # story-view's no-poll pattern: refresh button + one load, no timer
        self.assertIn("refresh-btn", self.js)
        self.assertNotIn("setInterval(", self.js)
        self.assertNotIn("HnghPoll", self.js)

    def test_fail_closed_gate_schema_and_entries(self):
        # exact envelope gate (coordinator resolution 2026-09-15: no
        # feed-level stamp exists, so no generatedAt gating) — the
        # page's anchoring still comes only from feed data, never a
        # client-prayed Date
        self.assertIn("feedOk(feed)", self.js)
        self.assertLess(self.js.index("feedOk(feed)"),
                        self.js.index("renderAll("),
                        "envelope gate runs before rendering")
        self.assertIn("Array.isArray(feed.entries)", self.js)
        self.assertIn("tsExtent(", self.js)
        self.assertNotIn("toISOString", self.js)
        self.assertNotRegex(self.js, r"new Date\(\)")

    def test_esc_and_owned_style_tag_not_style_css(self):
        self.assertIn("function esc(", self.js)
        self.assertGreaterEqual(self.js.count("esc(") - 1, 4)
        self.assertIn("<style>", self.js)
        self.assertIn("document.head.appendChild", self.js)

    def test_refs_are_jailed_repo_relative_only(self):
        # links go through the jailed /hngh-docs/docs/ route; only a
        # repo-relative docs/ path earns a link, anything else renders
        # as plain text (fail closed, no arbitrary-url anchor)
        self.assertIn("/hngh-docs/docs/", self.js)
        self.assertLess(self.js.index('startsWith("docs/")'),
                        self.js.index('href="'),
                        "ref jail check precedes any href build")
        # the href is built only from the jailed path variable, escaped
        m = re.search(r'href="\' \+ esc\(([a-zA-Z]+)\)', self.js)
        self.assertIsNotNone(m, "href must be built from the jailed path var")
        self.assertIn("jail", m.group(1))

    def test_cap_and_overflow_marker(self):
        self.assertIn("DISPLAY_CAP = 100", self.js)
        self.assertIn("(' of '", self.js.replace("' of '", "(' of '"))
        self.assertIn(" shown)", self.js)


# ---------------------------------------------------------------------------
# headless execution of the pure helpers over fixture payloads
# ---------------------------------------------------------------------------

def helpers_source():
    """Slice the pure-function head of history-view.js (everything up to
    the "// ---- boot ----" mark) and strip the IIFE opener + 'use
    strict' so the slice is a plain function body the way
    test-dashboard-p0.GraphTwoShellLayout extracts served functions."""
    v = src("history-view.js")
    head = v[:v.index("// ---- boot ----")]
    body = head[head.index("(function () {") + len("(function () {"):]
    return body.replace("'use strict';", "", 1)


def helpers_js():
    return ("const H = (new Function(%s +\n"
            "'\\nreturn {feedOk, tsExtent, visibleEntries, rowHtml,"
            " renderRows,\\n overflowLine};'))();\n" % json.dumps(helpers_source()))


class HistoryViewPure(unittest.TestCase):
    """Fixture-driven execution: valid feed, empty entries, missing
    generated_at, 600-entry cap + overflow, source filter selection."""

    def exec_rows(self, payload, **opts):
        return run_node(
            helpers_js() +
            "const feed = %s;\n"
            "if (!H.feedOk(feed)) { console.log('GATE_FAIL');"
            " process.exit(0); }\n"
            "const rows = H.visibleEntries(feed, %s, %s);\n"
            "console.log(JSON.stringify({extent: H.tsExtent(rows),"
            " rows: rows, html: H.renderRows(rows, %d)}));"
            % (json.dumps(payload),
               json.dumps(opts.get("source", "")),
               json.dumps(opts.get("kind", "")),
               opts.get("cap", 100)))

    def test_valid_feed_renders_newest_first_with_ts_extent(self):
        # the producer's contract is ts-desc input; the view preserves it
        payload = feed([entry(4, "journal"), entry(3, "records"),
                        entry(2, "report"), entry(1)])
        out = json.loads(self.exec_rows(payload))
        self.assertEqual(out["extent"], {"oldest": "2026-09-11T12:00:00Z",
                                         "newest": "2026-09-14T12:00:00Z"})
        self.assertEqual(len(out["rows"]), 4)
        # newest-first order comes straight from the feed
        self.assertEqual(out["rows"][0]["key"], "journal:k0004")
        self.assertEqual(out["rows"][3]["key"], "gitlog:k0001")
        # row html: ts, source chip, summary present; HTML-escaped
        html = out["html"]
        self.assertIn("2026-09-14T12:00:00Z", html)
        self.assertIn("hv-chip-gitlog", html)
        self.assertIn("entry 4 from journal", html)
        self.assertNotIn("<script", html)

    def test_empty_entries_render_placeholder_not_error(self):
        # an empty envelope is valid per the producer spec: empty state,
        # no extent, never a fabricated span
        payload = feed([])
        out = json.loads(self.exec_rows(payload))
        self.assertEqual(out["rows"], [])
        self.assertIsNone(out["extent"])
        self.assertIn("hv-empty", out["html"])

    def test_missing_schema_fails_closed(self):
        # coordinator resolution: the gate is schema + entries array,
        # NOT a feed-level stamp (the pinned envelope has none)
        payload = {"entries": [entry(1)]}
        out = self.exec_rows(payload)
        self.assertIn("GATE_FAIL", out)

    def test_wrong_schema_fails_closed(self):
        payload = {"schema": "history/2", "entries": [entry(1)]}
        self.assertIn("GATE_FAIL", self.exec_rows(payload))

    def test_non_array_entries_fails_closed(self):
        payload = {"schema": "history/1", "entries": "nope"}
        self.assertIn("GATE_FAIL", self.exec_rows(payload))

    def test_entries_with_no_usable_ts_extent_is_null(self):
        payload = feed([{"key": "x", "summary": "s", "source": "report"}])
        out = json.loads(self.exec_rows(payload))
        self.assertIsNone(out["extent"])

    def test_six_hundred_entries_cap_and_overflow_marker(self):
        # ts-desc like the real feed: newest first
        entries = [entry(i) for i in range(599, -1, -1)]
        out = json.loads(self.exec_rows(feed(entries)))
        self.assertEqual(len(out["rows"]), 600)  # visible = whole filtered set
        self.assertEqual(out["rows"][0]["key"], "gitlog:k0599")
        # the cap lives in the render layer, overflow line tells the truth
        self.assertEqual(out["html"].count('class="hv-row"'), 100)
        self.assertIn("(100 of 600 shown)", out["html"])

    def test_source_filter_selection(self):
        # ts-desc input
        entries = [entry(4, "journal"), entry(3, "report"),
                   entry(2, "report"), entry(1)]
        out = json.loads(self.exec_rows(feed(entries), source="report"))
        self.assertEqual([e["key"] for e in out["rows"]],
                         ["report:k0003", "report:k0002"])
        # kind filter on top of source
        out2 = json.loads(self.exec_rows(feed(entries),
                                         source="report", kind="alert"))
        self.assertEqual([e["key"] for e in out2["rows"]], ["report:k0003"])
        # rows keep cap behavior under filters (ts-desc: newest kept)
        many = [entry(i, "report") for i in range(150, 0, -1)]
        out3 = json.loads(self.exec_rows(feed(many), source="report"))
        self.assertEqual(len(out3["rows"]), 150)
        self.assertEqual(out3["rows"][0]["key"], "report:k0150")
        self.assertEqual(out3["html"].count('class="hv-row"'), 100)
        self.assertIn("(100 of 150 shown)", out3["html"])


# ---------------------------------------------------------------------------
# served-route smoke test: GET /history.json 200 + schema key
# ---------------------------------------------------------------------------

class HistoryEndpoint(unittest.TestCase):
    """GET /history.json over a bound ephemeral server; builder seamed
    (same harness pattern as test-graph-feed-refresh.py)."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        dash = self.tmp / "dash"
        dash.mkdir()
        # the static-file fallback needs the real served files to exist
        # (index.html for the token injection, history.html + the view)
        for name in ("index.html", "history.html", "history-view.js"):
            shutil.copy(DASH / name, dash / name)
        for name in ("operator-items.json", "operator-dismissed.json",
                     "readout.json"):
            (dash / name).write_text("{}")
        self.ds = _load("dashboard_server_history", "dashboard-server.py")
        self.ds.DASHBOARD = str(dash)
        self.ds.TOKEN_FILE = str(dash / "token.txt")
        self.ds.load_token()
        self.payload = feed([entry(1), entry(2, "report")])
        self._real = self.ds.history_feed.build
        self.ds.history_feed.build = lambda *a, **k: json.loads(
            json.dumps(self.payload))
        self.ds._history_cache = (0.0, None)  # cold, per-test
        self.ds.Handler.protocol_version = "HTTP/1.1"
        self.httpd = self.ds.ThreadingHTTPServer(("127.0.0.1", 0),
                                                 self.ds.Handler)
        threading.Thread(target=self.httpd.serve_forever,
                         daemon=True).start()
        self.port = self.httpd.server_address[1]

    def tearDown(self):
        self.httpd.shutdown()
        self.httpd.server_close()
        self.ds.history_feed.build = self._real
        shutil.rmtree(self.tmp, ignore_errors=True)

    def get(self, path="/history.json"):
        c = http.client.HTTPConnection("127.0.0.1", self.port, timeout=10)
        c.request("GET", path, headers={"Connection": "close"})
        r = c.getresponse()
        data = r.read()
        c.close()
        if path.endswith(".json"):
            return r.status, json.loads(data) if data else {}
        return r.status, data

    def test_serves_200_with_history_schema_key(self):
        st, body = self.get()
        self.assertEqual(st, 200)
        self.assertEqual(body.get("schema"), "history/1")
        self.assertIsInstance(body.get("entries"), list)
        self.assertEqual(len(body["entries"]), 2)

    def test_page_served_and_view_registered_in_index(self):
        st, body = self.get("/history.html")
        self.assertEqual(st, 200)
        self.assertIn(b"history-view.js", body)
        st2, idx = self.get("/index.html")
        self.assertEqual(st2, 200)
        self.assertIn(b'data-tab="history"', idx)

    def test_docs_jail_serves_real_doc_and_404s_traversal(self):
        # the history view's ref links target /hngh-docs/docs/<repo-
        # relative path>.md — the jail must serve a real kernel doc and
        # fail closed on traversal/absence, same as the media jail.
        # DOCS_DOCS is HNGH_REPO (env override) + /docs; probe a record.
        target = Path(self.ds.DOCS_DOCS) / "records"
        if not target.is_dir():
            self.skipTest("kernel docs/records tree not present")
        probe = sorted(target.glob("*.md"))[0]
        st, body = self.get("/hngh-docs/docs/records/" + probe.name)
        self.assertEqual(st, 200)
        self.assertTrue(body)  # markdown served
        st2, _ = self.get("/hngh-docs/docs/..%2f..%2fsecret.md")
        self.assertEqual(st2, 404)
        st3, _ = self.get("/hngh-docs/docs/records/nope.md")
        self.assertEqual(st3, 404)
        st4, _ = self.get("/hngh-docs/docs/records/" + probe.name + ".bak")
        self.assertEqual(st4, 404)


if __name__ == "__main__":
    unittest.main()
