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
    # dashboard/ is quarantined machine data (automation/.gitignore);
    # a fresh clone (CI runner) has no served sources to contract-check
    if not (DASH / "index.html").is_file():
        raise unittest.SkipTest("dashboard/ not present (quarantined machine data)")
    return (DASH / name).read_text()


def run_node(script):
    """Run a node -e script; nonzero exit or stderr -> AssertionError.
    Lets tests execute extracted dashboard-JS functions for real instead
    of only pattern-matching their text. Skips when node is absent so a
    browser-less CI runner still passes."""
    import shutil
    import subprocess
    node = shutil.which("node")
    if node is None:
        raise unittest.SkipTest("node not available for JS execution")
    out = subprocess.run([node, "-e", script], capture_output=True,
                         text=True, timeout=30)
    if out.returncode != 0:
        raise AssertionError("node script failed: " + out.stderr.strip()[:400])
    return out.stdout


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
        self.assertIn("/hngh-docs/plans/", v)

    def test_filter_state_survives_refresh_and_keeps_focus(self):
        v = src("plans-view.js")
        self.assertIn("ui = { q: '', status: '' }", v)
        self.assertIn("value=\"' + esc(ui.q)", v, "search value restored on re-render")
        self.assertIn("renderRows(); // rows-only: focus kept", v)


class GraphViewVocabularyAndAutoRefresh(unittest.TestCase):
    """graph-view contract (2026-09-14): new node kinds render + chip, and
    the 60s auto-refresh goes through the shared helper with a panel-
    visibility guard so a parked graph tab never fetches. Textual contract
    on the served source, same discipline as the rest of this suite."""

    def kinds_segment(self):
        v = src("graph-view.js")
        return v[v.index("var KINDS"):v.index("];", v.index("var KINDS"))]

    def test_new_kinds_in_size_map_and_chips(self):
        v = src("graph-view.js")
        size = v[v.index("var KIND_SIZE"):v.index("};", v.index("var KIND_SIZE"))]
        for size_entry, kind in (("'jcode-session': 4", "jcode-session"),
                                 ("'swarm': 6", "swarm")):
            self.assertIn(size_entry, size, "KIND_SIZE missing " + size_entry)
            self.assertIn("'" + kind + "'", self.kinds_segment(),
                          "KINDS chips missing " + kind)

    def test_state_vocabulary_untouched(self):
        v = src("graph-view.js")
        states = v[v.index("var STATES"):v.index("];", v.index("var STATES"))]
        self.assertEqual(states, "var STATES = ['healthy', 'stale', 'alerting', 'neutral'")
        for kind in ("jcode-session", "swarm"):
            self.assertNotIn(kind, states, "kind leaked into the state vocabulary")

    def test_auto_refresh_through_helper_skips_hidden_panel(self):
        v = src("graph-view.js")
        self.assertNotIn("setInterval(", v, "graph-view still has a raw timer")
        self.assertIn("POLL_MS = 60000", v, "60s auto-refresh cadence")
        self.assertIn("HnghPoll.start(autoLoad, { interval: POLL_MS })", v,
                      "auto-refresh must reuse the shared poll helper")
        self.assertIn("function graphTabVisible()", v)
        auto = v[v.index("function autoLoad()"):
                 v.index("}", v.index("function autoLoad()"))]
        self.assertIn("graphTabVisible()", auto)
        self.assertIn("load()", auto)
        self.assertLess(auto.index("graphTabVisible()"), auto.index("load()"),
                        "visibility gate runs before the fetch")
        self.assertIn("'p-graph'", v, "guard keys on the graph panel id")


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


class HonestDismiss(unittest.TestCase):
    def test_armed_state_revalidates_on_fetch(self):
        # finding 2026-09-10 dashboard-logs:2 — a stale arm must not
        # survive a fetch whose feed no longer shows the item live; the
        # revalidation lives at the data boundary (fetchOpState), not the
        # render path.
        a = src("app.js")
        f = a[a.index("function fetchOpState"):a.index("function dismissedToday")]
        self.assertIn("it.id === armedId && !opState.dismissed[it.id]", f)
        self.assertIn("armedId = null", f)


class OpRerenderPreloadSafety(unittest.TestCase):
    def test_op_rerender_cannot_crash_before_first_render(self):
        # finding 2026-09-10 dashboard-logs:1 (parked, premise stale) — an
        # op-state update landing before the initial spine render must
        # route to the known empty state, never crash: both entry points
        # early-return on lastRender.d (assigned atomically with res in
        # renderLogs), the renderLogs chain consumes no res, and the sole
        # res consumer (renderHeader) is call-site guarded.
        a = src("app.js")
        both = a[a.index("function rerenderWithOpState"):a.index("var armedId = null")]
        rwo = both[:both.index("function rerenderOp")]
        ro = both[both.index("function rerenderOp"):]
        self.assertIn("if (lastRender.d === undefined) return;", rwo)
        self.assertIn("if (lastRender.res) renderHeader(", rwo)
        self.assertLess(rwo.index("lastRender.d === undefined"), rwo.index("renderLogs("))
        self.assertLess(ro.index("lastRender.d === undefined"), ro.index("renderLogs("))
        self.assertLess(ro.index("opRerenders.forEach"), ro.index("renderLogs("))
        logs = a[a.index("function renderLogs("):a.index("// ---------- mini markdown")]
        self.assertIn("lastRender = { d: d, spine: spine, res: res };", logs)
        self.assertNotIn("res.", logs)


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


class GraphTwoShellLayout(unittest.TestCase):
    """Two-shell layout contract (deep-task node sg-layout-density,
    2026-09-14): the default feed carries ~125 jcode-session nodes, so
    they move to a secondary outer shell instead of crowding the ~225
    kernel-side nodes at R=190. Textual contract + real execution of the
    extracted layout over a synthetic feed via node (both skip-guarded:
    dashboard/ is quarantined machine data; node may be absent)."""

    def source(self):
        return src("graph-view.js")

    def test_layout_contract_text(self):
        v = self.source()
        self.assertIn("function layout(nodes)", v)
        self.assertIn("var R2 = R + 34 * Math.pow(Math.max(0, outer.length - 1), 0.42);",
                      v, "outer shell radius growth formula changed")
        self.assertIn("if (k === 'jcode-session' || k === 'swarm') outer.push(nodes[i]);",
                      v, "outer-shell kind set changed")
        self.assertIn("var R = 190, phi", v, "kernel shell radius unchanged")
        self.assertIn("cam.r = Math.max(640, (layout.shellRadius || 190) * 1.9);",
                      v, "camera re-fit to the outer shell")
        self.assertIn("Math.min(W, H) / ((layout.shellRadius || 190) * 2.4);",
                      v, "2D projection scale re-fit to the outer shell")
        self.assertNotIn("var cx = W / 2, cy = H / 2, sc = Math.min(W, H) / 480;",
                         v, "fixed 2D scale must be gone")

    def extract_body(self):
        import json
        v = self.source()
        start = v.index("function layout(nodes)")
        end = v.index("var root, wrap", start)
        return json.dumps(v[start:end] + "\nreturn layout;")

    def test_executed_layout_invariants(self):
        # real execution, not just text matching: extract the served
        # layout function, run its checkInvariants hook (unpositioned,
        # NaN/Inf, duplicate keys, kernel at origin, per-kind shell
        # radius) over a synthetic two-shell feed via node
        import json
        feed = {"nodes": [{"id": "kernel", "kind": "kernel"}]}
        for i in range(20):
            feed["nodes"].append({"id": "leg:%d" % i, "kind": "leg"})
        for i in range(30):
            feed["nodes"].append({"id": "research-line:%d" % i,
                                  "kind": "research-line"})
        for i in range(60):
            feed["nodes"].append({"id": "jcode-session:%d" % i,
                                  "kind": "jcode-session"})
        feed["nodes"].append({"id": "swarm:0", "kind": "swarm"})
        out = run_node(
            "const layout = (new Function(%s))();\n"
            "const feed = %s;\n"
            "layout.checkInvariants(feed);\n"
            "console.log('INVARIANTS_OK nodes=' + feed.nodes.length +\n"
            "  ' shell=' + layout.shellRadius);"
            % (self.extract_body(), json.dumps(feed)))
        self.assertIn("INVARIANTS_OK nodes=112", out)
        self.assertIn("shell=379.8", out)  # 61 outer: 190+34*60^0.42

    def test_executed_layout_keeps_small_kernel_side_feed_unchanged(self):
        # no outer-kind nodes -> positions must match the legacy single-
        # shell algorithm exactly (byte-identical JSON): the mitigation is
        # a no-op for a small graph
        import json
        legacy = """
function legacy(nodes) {
  var n = nodes.length, R = 190, phi = Math.PI * (3 - Math.sqrt(5));
  var pos = {};
  nodes.forEach(function (nd, i) {
    if (nd.kind === 'kernel') { pos[nd.id] = [0, 0, 0]; return; }
    var k = Math.max(0, i - 1), y = 1 - (2 * k + 1) / Math.max(1, n - 2);
    var r = Math.sqrt(Math.max(0, 1 - y * y)), th = phi * k;
    pos[nd.id] = [R * r * Math.cos(th), R * y, R * r * Math.sin(th)];
  });
  return pos;
}
return legacy;
"""
        nodes = [{"id": "kernel", "kind": "kernel"}]
        for i in range(40):
            nodes.append({"id": "leg:%d" % i, "kind": "leg"})
        out = run_node(
            "const layout = (new Function(%s))();\n"
            "const legacy = (new Function(%s))();\n"
            "const nodes = %s;\n"
            "const a = JSON.stringify(legacy(nodes));\n"
            "const b = JSON.stringify(layout(nodes));\n"
            "if (a !== b) { console.error('kernel-side layout diverged');\n"
            "  process.exit(1); }\n"
            "console.log('BACKCOMPAT_OK nodes=' + nodes.length);"
            % (self.extract_body(), json.dumps(legacy), json.dumps(nodes)))
        self.assertIn("BACKCOMPAT_OK nodes=41", out)


class GraphCameraPreserve(unittest.TestCase):
    """Camera/selection/filter preservation across the 60s auto-refresh
    (deep-task node sg-load-camera-preserve, 2026-09-14): a reload must not
    yank the camera, clear the selection, or drop filter/search/spin state.
    Textual contract + headless execution of the pure snapshot/restore
    helpers via node (same discipline as GraphTwoShellLayout)."""

    def source(self):
        return src("graph-view.js")

    def test_preserve_contract_text(self):
        v = self.source()
        self.assertIn("function snapshotView()", v)
        self.assertIn("function restoreView(snap,", v)
        load = v[v.index("  function load()"):v.index("  window.GraphView")]
        self.assertIn("var first = (data === null)", load)
        self.assertIn("snapshotView()", load)
        self.assertIn("restoreView(snap, first)", load)
        self.assertIn("select(snap.sel)", load, "selection re-applied")
        self.assertIn("clearSel()", load, "vanished selection cleared")
        self.assertIn("snap.sel && byId(snap.sel)", load)
        for token in ("kindOff[k] = true", "stateOff[s] = true",
                      "sb.value = keepQ", "setSpin(true)"):
            self.assertIn(token, load, "state not re-applied: " + token)
        self.assertIn("hash", load.lower(), "hash navigation must win")
        first_branch = load[:load.index("restoreView(snap, first)")]
        self.assertNotIn("resetView()", first_branch.replace(
            "// still re-fits to the outer shell via resetView.", ""),
            "resetView must only run on first load, never on refresh")

    def extract_helpers(self):
        import json
        v = self.source()
        start = v.index("function clamp(v, lo, hi)")
        end = v.index("snapshotView._isFirstLoad")
        # clamp/resetView/snapshotView/restoreView only; the real layout()
        # sits between parseDetail and checkInvariants and is NOT included —
        # the harness injects a stub whose shellRadius it controls.
        head = v[start:v.index("// Deterministic fibonacci-sphere layout")]
        tail_start = v.index("  function resetView()")
        tail = v[tail_start:end]
        pre = ("var COLORS={healthy:'#3fb950'}, KIND_SIZE={leg:6.5};\n"
               "var data=null, pos=null, selId=null, spinning=false;\n"
               "var kindOff={}, stateOff={};\n"
               "var cam={th:0.6,ph:0.35,r:640};\n"
               "function layout(nodes){}\nlayout.shellRadius=190;\n")
        return json.dumps(pre + head + tail +
                          "\nreturn {snapshotView, restoreView, cam, layout,"
                          "\n setSel: function(id){ selId = id; },"
                          "\n setSpin: function(b){ spinning = b; }};")

    def test_executed_snapshot_restore(self):
        import json
        out = run_node(
            "const h = (new Function(%s))();\n"
            "const {snapshotView, restoreView} = h;\n"
            "const cam = h.cam, layout = h.layout;\n"
            "let fails = [];\n"
            "function eq(name, got, want) {\n"
            "  if (JSON.stringify(got) !== JSON.stringify(want))\n"
            "    fails.push(name + ' got=' + JSON.stringify(got) +\n"
            "      ' want=' + JSON.stringify(want)); }\n"
            "// 1. snapshot captures the live view\n"
            "cam.th=1.2; cam.ph=-0.5; cam.r=900; h.setSel('leg:3'); h.setSpin(true);\n"
            "const snap = snapshotView();\n"
            "eq('snap', snap, {th:1.2,ph:-0.5,r:900,sel:'leg:3',spin:true});\n"
            "// 2. first load re-fits (small feed -> 640)\n"
            "layout.shellRadius=190;\n"
            "cam.th=9; cam.ph=9; cam.r=999;\n"
            "restoreView(null, true);\n"
            "eq('first', cam, {th:0.6,ph:0.35,r:640});\n"
            "// 3. refresh preserves orbit + zoom at the same shell\n"
            "cam.th=0; cam.ph=0; cam.r=640;\n"
            "restoreView(snap, false);\n"
            "eq('preserve', cam, {th:1.2,ph:-0.5,r:900});\n"
            "// 4. grow-only: bigger shell pulls back a close-up view\n"
            "layout.shellRadius=450;\n"  # minFit = 855
            "const close = {th:1.2,ph:-0.5,r:700,sel:'leg:3',spin:true};\n"
            "cam.th=0; cam.ph=0; cam.r=640;\n"
            "restoreView(close, false);\n"
            "eq('grow', cam, {th:1.2,ph:-0.5,r:855});\n"
            "// 5. operator zoomed far out stays (no yank inward)\n"
            "const far = {th:1.2,ph:-0.5,r:1200,sel:'leg:3',spin:true};\n"
            "cam.th=0; cam.ph=0; cam.r=640;\n"
            "restoreView(far, false);\n"
            "eq('far', cam, {th:1.2,ph:-0.5,r:1200});\n"
            "if (fails.length) { console.error(fails.join('\\n'));\n"
            "  process.exit(1); }\n"
            "console.log('CAMERA_OK');"
            % self.extract_helpers())
        self.assertIn("CAMERA_OK", out)




class VerdictOverride(unittest.TestCase):
    """Tranche 2026-10-03 slice 1: ONE verdict computation. The open-items
    warn override used to live only in renderHeader, so Camp (which calls
    HnghOps.verdict directly) could show ALL CLEAR beside a NEEDS ATTENTION
    header on the same screen. The override moves into verdictOf; renderHeader
    keeps only rendering."""

    def test_open_items_pull_verdict_to_warn(self):
        a = src("app.js")
        dv = a[a.index("function digestVerdict"):a.index("function parseOperators")]
        oc = a[a.index("function openOpCount"):a.index("function rerenderWithOpState")]
        vo = a[a.index("function verdictOf"):a.index("function renderHeader")]
        sr = a[a.index("function selfReviewAlerts"):a.index("function verdictOf")]
        script = (
            "var opState = { items: [{id:'a', status:'open'}], dismissed: {} };\n"
            "var rqState = { rows: [] };\n"
            + dv + "\n" + oc + "\n" + sr + "\n" + vo + "\n"
            "var r = verdictOf({}, {verdict: {state: 'clear'}});\n"
            "if (r.level !== 'warn' || r.label !== 'Needs attention')\n"
            "  throw new Error('open override missing: ' + JSON.stringify(r));\n"
            "if (r.reasons.join('|') !== '1 open operator item')\n"
            "  throw new Error('reason wrong: ' + r.reasons.join('|'));\n"
            "opState.items = [];\n"
            "var r0 = verdictOf({}, {verdict: {state: 'clear'}});\n"
            "if (r0.level !== 'ok' || r0.label !== 'clear')\n"
            "  throw new Error('clean spine mutated: ' + JSON.stringify(r0));\n"
            "opState.items = [{id: 'b', status: 'open'}, {id: 'c', status: 'open'}];\n"
            "var rn = verdictOf({}, {verdict: {state: 'clear', reasons: ['x']}});\n"
            "if (rn.reasons.join('|') !== 'x|2 open operator items')\n"
            "  throw new Error('plural/concat wrong: ' + rn.reasons.join('|'));\n"
            "var rl = verdictOf({digest: 'no repairs needed'}, null);\n"
            "if (rl.label !== 'Needs attention' || rl.level !== 'warn')\n"
            "  throw new Error('legacy fallback not overridden: ' + JSON.stringify(rl));\n"
            "console.log('VERDICT_OK');\n"
        )
        self.assertIn("VERDICT_OK", run_node(script))

    def test_render_header_renders_shared_verdict_only(self):
        a = src("app.js")
        rh = a[a.index("function renderHeader"):a.index("function headerNoSignal")]
        self.assertNotIn("v.level = 'warn'", rh,
                         "renderHeader still carries its own override")
        self.assertIn("verdictOf(d, spine)", rh)
        # attention count + title badge still read openOp directly
        self.assertIn("document.title = openOp > 0", rh)

    def test_camp_verdict_not_duplicated(self):
        v = src("overview-view.js")
        vb = v[v.index("function verdictBlock"):v.index("function opBlock")]
        self.assertNotIn("reasons.push(ops.open", vb,
                         "Camp re-derives the open-items reason")
        self.assertIn("window.HnghOps.verdict(d, spine)", vb)




class OpRowDecompose(unittest.TestCase):
    """Tranche 2026-10-03: operator rows render producer-first instead of
    one dense pipe string; the full raw text stays on the row title.
"""

    def setUp(self):
        self.js = src("app.js")

    def test_decompose_helper_shape(self):
        m = re.search(r"function decomposeOpText\(text\) \{[\s\S]*?\n  \}",
                      self.js)
        self.assertTrue(m, "decomposeOpText missing")
        script = m.group(0) + (";console.log(JSON.stringify(["
            "decomposeOpText('19-ux-review.sh | alert | ux-review:x'),"
            "decomposeOpText('no shape here'),"
            "decomposeOpText(null)]))")
        import json
        import subprocess
        out = json.loads(subprocess.run(
            ["node", "-e", script], capture_output=True, text=True,
            check=True).stdout)
        self.assertEqual(out, [
            {"producer": "19-ux-review.sh", "kind": "alert",
             "rest": "ux-review:x"},
            None, None])

    def test_rows_render_producer_first_with_raw_title(self):
        self.assertIn('class="oprod"', self.js)
        self.assertIn('class="opkind"', self.js)
        self.assertIn(
            """return '<div class="opitem" title="' + esc(it.text) + '">' +""",
            self.js)

    def test_optext_word_breaks(self):
        css = src("style.css")
        self.assertIn("word-break: break-word;", css)
        self.assertIn(".oprod {", css)
        self.assertIn(".opkind {", css)





class SelfReviewSurfacing(unittest.TestCase):
    """Tranche 2026-10-03: dash-selfreview files staleness alerts into
    the report queue, but the verdict ignored them — the page said ALL
    CLEAR while the queue held "feed-fresh:operator-items.json:
    unacceptable-now". Self-review rows now feed verdictOf (client-only:
    rqState.rows is already fetched)."""

    def setUp(self):
        self.js = src("app.js")

    def _extract(self):
        fns = []
        for name in ("selfReviewAlerts", "selfReviewChecks"):
            m = re.search(r"function %s\(rows\) \{[\s\S]*?\n  \}" % name,
                          self.js)
            self.assertTrue(m, name + " missing")
            fns.append(m.group(0))
        return "\n".join(fns)

    def test_alert_filter_and_check_names(self):
        script = self._extract() + (
            ";console.log(JSON.stringify(["
            "selfReviewAlerts([{first: '[dash-selfreview] "
            "feed-fresh:operator-items.json: unacceptable-now - stale 1501s'},"
            "{first: '[dash-selfreview] spend: on budget'},"
            "{first: 'operator item abc handled'},"
            "{first: '[dash-selfreview] slow-unit:x: failing 2 checks'}]).length,"
            "selfReviewChecks([{first: '[dash-selfreview] "
            "feed-fresh:operator-items.json: unacceptable-now - stale 1501s'},"
            "{first: '[dash-selfreview] slow-unit:x: failing 2 checks'}]),"
            "selfReviewAlerts([]).length]))")
        import json
        import subprocess
        out = json.loads(subprocess.run(
            ["node", "-e", script], capture_output=True, text=True,
            check=True).stdout)
        self.assertEqual(out, [2,
            ["feed-fresh:operator-items.json", "slow-unit:x"], 0])

    def test_verdictof_consumes_rqstate_rows(self):
        self.assertIn("selfReviewChecks(rqState.rows)", self.js)
        self.assertIn("dashboard self-review failing: ' + c", self.js)

    def test_glossary_names_kernel_gate_boundary(self):
        self.assertIn("the last ceremony commit lives on the Plans tab",
                      src("console.html"))




class TokenFailSafe(unittest.TestCase):
    """Tranche 2026-10-03: the served page carries two hngh-token metas
    (server-injected real one, then the empty file:// placeholder).
    querySelector stops at the first match in document order, which is
    fine served but wrong on any page order change; read the first
    NON-EMPTY content across all matches instead.
    (Extracted from test-broadsheet-view.py before the broadsheet
    suite retired with the 2026-10-03 control-room cut.)
    """

    def test_first_non_empty_across_all_views(self):
        qsa = "querySelectorAll('meta[name=" + '"' + "hngh-token" + '"' + "]')"
        qs = "document.querySelector('meta[name=" + '"' + "hngh-token" + '"' + "]')"
        for name in ("app.js", "desk-view.js"):
            js = src(name)
            self.assertIn(qsa, js, name)
            self.assertNotIn(qs, js, name)
            self.assertIn("if (v) return v;", js, name)



class ControlRoomShell(unittest.TestCase):
    """Harness program phase C2 (2026-10-04): the control-room shell is
    the primary dashboard surface — live megastructure map, honest 2D
    fallback, attention rail fed by operator-items.json, dateline with
    edition age + open count. The map refreshes its live layer every
    poll instead of binding once (the old broadsheet map froze at first
    build)."""

    def setUp(self):
        self.html = src("index.html")
        self.js = src("map.js")

    def test_shell_structure(self):
        for needle in ('id="map3d"', 'id="map-fallback"',
                       'id="attention"', 'id="dateline"',
                       'src="map.js"', 'href="console.html"'):
            self.assertIn(needle, self.html)

    def test_map_carries_live_layer_and_fauna(self):
        self.assertIn("var MAP_SEEDS", self.js)
        self.assertIn("mapState.live", self.js)
        self.assertIn("Math.min(openCount || 0, 8)", self.js)
        self.assertIn("s.ring.color.setHex(openCount > 0 ? 0x8a6b2a"
                      " : 0x4a6b3a)", self.js)

    def test_poll_refreshes_map_every_cycle(self):
        self.assertIn("fetchJSON('operator-items.json')", self.js)
        self.assertIn("fetchJSON('fleet.json')", self.js)
        self.assertIn("setTimeout(pollLoop, prefs().pollMs)", self.js)
        self.assertIn("scene.background = new THREE.Color(0x191b1f)", self.js)
        self.assertNotIn("alpha: true", self.js)
        self.assertIn("sys.queue_depth != null", self.js)
        # rebuilt-when-built: init must refresh, not freeze at first build
        self.assertIn("if (mapState.built) { mapRefresh(fleetNodes,"
                      " openCount); return; }", self.js)

    def test_attention_rail_points_at_the_verbs(self):
        self.assertIn("the nerve center holds the verbs", self.js)
        self.assertIn("items.slice(0, prefs().attentionCap)", self.js)

    def test_edition_age_math(self):
        m = re.search(r"function editionAge\([\s\S]*?\n\}", self.js)
        self.assertTrue(m, "editionAge missing")
        script = m.group(0) + (
            ";var t0 = Date.parse('2026-10-04T20:00:00Z');"
            "console.log(JSON.stringify(["
            "editionAge('2026-10-04T20:00:00Z', t0 + 12 * 60000),"
            "editionAge('2026-10-04T20:00:00Z', t0 + 96 * 60000),"
            "editionAge('garbage', t0)]))")
        import json
        import subprocess
        out = json.loads(subprocess.run(
            ["node", "-e", script], capture_output=True, text=True,
            check=True).stdout)
        self.assertEqual(out, [
            {"text": "12m old", "stale": False},
            {"text": "1h 36m old", "stale": True},
            None])



class ControlRoomSettings(unittest.TestCase):
    """C3: a settings drawer on the control room; console Routes tab folds away."""

    def test_drawer_and_prefs_key_pinned(self):
        shell = src("index.html")
        self.assertIn('id="settings"', shell)
        self.assertIn("settings", shell)
        js = src("map.js")
        self.assertIn("localStorage.getItem('control-room-prefs')", js)
        for key in ("attentionCap", "rotate", "pollMs"):
            self.assertIn(key, js)

    def test_routes_tab_folded_into_plans(self):
        console = src("console.html")
        self.assertNotIn("tab-routes", console)
        self.assertNotIn("p-routes", console)
        self.assertIn("routes.html", console)
        app = src("app.js")
        self.assertNotIn("'routes-root'", app)




if __name__ == "__main__":
    unittest.main()
