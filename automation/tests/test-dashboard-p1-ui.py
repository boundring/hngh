#!/usr/bin/env python3
"""Dashboard P1 UI wave contract tests, hermetic.

dashboard/ UI files are gitignored runtime artifacts, so the honest tracked
regression is a textual contract on the served sources — same discipline as
test-dashboard-p0.py. Covers the P1 server wiring: token-guarded POSTs, the
SSE client with poll fallback, per-session slice polling, spawn/tile
confirm patterns, the report-queue mark-read surface, the telemetry stat,
and poll hygiene (no raw setInterval outside the standalone gantt page).
No network, no server, no dashboard files written.
"""
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


class TokenPlumbing(unittest.TestCase):
    def test_meta_token_read_and_header_attached(self):
        a = src("app.js")
        self.assertIn("meta[name=\"hngh-token\"]", a)
        self.assertIn("'X-Hngh-Token': hnghToken()", a)
        # every view POST rides the shared helper or carries the header
        self.assertIn("postJson('/operator-item/dismiss', { id: id })", a)
        self.assertIn("window.HnghOps.post(url, body, ms)",
                      src("research-view.js"))
        for v in ("system-view.js", "feedback-view.js"):
            self.assertIn("'X-Hngh-Token': (window.HnghOps ? window.HnghOps.token() : '')",
                          src(v), v)

    def test_403_surfaces_expired_chip_not_silence(self):
        a = src("app.js")
        self.assertIn("if (r.status === 403) tokenExpiredChip()", a)
        self.assertIn("session expired", a)
        self.assertIn("location.reload", a)
        # the two views with their own fetch wrappers still surface it
        for v in ("system-view.js", "feedback-view.js"):
            self.assertIn("window.HnghOps.expired()", src(v), v)


class SseClient(unittest.TestCase):
    def test_subscribe_with_poll_fallback_and_pause(self):
        a = src("app.js")
        self.assertIn("new EventSource('/events')", a)
        # a change event refreshes the core feeds and the mounted view
        self.assertIn("es.addEventListener('change', function () {", a)
        self.assertIn("refreshCurrentView();", a)
        # two SSE errors fall back to the P0 poll; push pauses the poll
        self.assertIn("if (sseFails >= 2) { fallbackPoll(); return; }", a)
        self.assertIn("corePoll.stop(); corePoll = null;", a)
        # hidden tab closes the stream, visible reopens it
        self.assertIn("sseStop(false); // SSE closes while hidden", a)
        self.assertNotIn("setInterval(", a)


class SessionSlicing(unittest.TestCase):
    def test_poll_slices_selected_session_only(self):
        v = src("sessions-view.js")
        self.assertIn("'/session/' + encodeURIComponent(sel) + '?tail=20'", v)
        self.assertIn("sliceFails >= 2", v)
        self.assertIn("fetchFeed(applyWhole); // degraded: the old whole-feed path", v)
        # the slice merge feeds the same render pipeline, no second renderer
        self.assertIn("r.detail = {", v)

    def test_filter_input_debounced_300ms(self):
        v = src("sessions-view.js")
        self.assertIn("clearTimeout(qTimer);", v)
        self.assertIn("}, 300);", v)


class SpawnTileControls(unittest.TestCase):
    def test_tail_button_is_confirm_gated_launcher_key(self):
        v = src("sessions-view.js")
        self.assertIn("data-tail-yes", v)
        self.assertIn("window.HnghOps.post('/spawn', { session: id, launcher: 'konsole-tail' })", v)
        # the client names the launcher key; it never supplies a command
        self.assertNotIn("subprocess", v)

    def test_tile_button_confirm_gated_with_honest_403(self):
        v = src("sessions-view.js")
        self.assertIn("armedTile", v)
        self.assertIn("window.HnghOps.post('/tile', { profile: 'duo', sessions: [r.id] })", v)
        # 403 (tiling disabled) reaches the operator verbatim, never silently
        self.assertIn("403: tiling disabled, verbatim", v)


class MarkRead(unittest.TestCase):
    def test_unread_rows_derived_from_ledger_mirror(self):
        a = src("app.js")
        self.assertIn("fetchText('reports.md')", a)
        self.assertIn("fetchText('report-cursor')", a)
        self.assertIn("rqState.unread = idx >= 0 ? rows.slice(idx + 1) : rows.slice()", a)
        self.assertIn("data-markread=", a)
        self.assertIn("postJson('/report-queue/mark-read', { id:", a)
        # the mirror is served: the symlinks exist and point at the ledger
        for name, target in (("reports.md", "../../docs/project/reports.md"),
                             ("report-cursor", "../../docs/project/report-cursor")):
            p = DASH / name
            self.assertTrue(p.is_symlink(), name)
            self.assertEqual(p.resolve().name, Path(target).name, name)


class TelemetryStat(unittest.TestCase):
    def test_spend_card_with_svg_sparkline(self):
        v = src("overview-view.js")
        self.assertIn("fetch('/telemetry.json', { cache: 'no-store' })", v)
        self.assertIn("24h spend $", v)
        self.assertIn("<polyline points=", v)
        self.assertIn("stroke=\"var(--accent)\"", v)  # palette owns the colors


class PollHygiene(unittest.TestCase):
    def test_no_raw_setinterval_outside_gantt(self):
        for js in DASH.glob("*.js"):
            if js.name == "gantt.js":  # standalone page, separate wave
                continue
            self.assertNotIn("setInterval(", js.read_text(), str(js))


if __name__ == "__main__":
    unittest.main()