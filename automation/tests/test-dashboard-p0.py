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


if __name__ == "__main__":
    unittest.main()
