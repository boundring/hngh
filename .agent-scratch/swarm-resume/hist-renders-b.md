# hist-renders-b: graph-view.js and story-view.js — how history-ish data renders today

Read-only skim of `automation/dashboard/graph-view.js` (870 lines, v5
2026-09-14) and `automation/dashboard/story-view.js` (304 lines,
visualization rung 1 step 3). Purpose: inventory what already renders
so a future history view does not duplicate it. Builds on
viz-graph-payload.md (graph pipeline), viz-history-payload.md
(sessions/telemetry payloads), rp-mirror.md (ledger symlink mirror).

## graph-view.js — snapshot view with recency-derived states

**Data source:** `GET /graph.json` only (built by
`jobs/graph-data.py`, served by `dashboard-server.py graph_feed()`,
per viz-graph-payload.md). One feed, fetched through the local
`fetchJson(url, 10s)` helper (AbortController + `cache: 'no-store'`,
lines 63-73). No other fetch.

**Refresh model:** shared `window.HnghPoll` timer, 60s auto-refresh
(`POLL_MS`, line 224; `wire()` lines 382-383) gated on the graph tab
being visible (`graphTabVisible()` 712-715 skips the fetch silently
when `#p-graph` is hidden). A second 5s poll ticks only the local
staleness badge ("live" / "data Ns old" / "feed error", `tickBadge()`
682-688) with no network. First poll tick performs the initial load;
`init` does not fetch separately (806-809).

**Render approach:** 3D perspective scene drawn with the plain 2D
canvas API (no WebGL, no three.js — operator's Chrome has WebGL dead).
Painter's algorithm, depth-sorted (`draw3d()` 451-520); preallocated
`Float32Array` screen buffers, zero allocation in the draw path
(`project()` 413-429). SVG flat fallback behind `?graph2d=1` or when
no canvas 2d (`render2d()` 815-847). Deterministic fibonacci-sphere
two-shell layout, kernel pinned at origin, outer shell radius grows
sublinearly with jcode-session/swarm count (`layout()` 170-196).

**History-ish content:** the view itself is a *current-state snapshot*
— all history is pre-baked into the payload's per-node `state` field:
`stale` = telemetry last event >2h (legs) or jcode session inactive
>10min, patrol `alerting` = FAIL in reports.md trailing 24h, etc.
(see viz-graph-payload.md state table). The view adds no time axis
and no lookback of its own. Recency is surfaced two ways: node color
via the state legend (COLORS/STATES, lines 43-55) and the data-age
badge. Node `detail` strings carry `k=v` pairs (parsed by
`parseDetail()` 75-84) which include recency facts, shown in the hover
tip and side panel (`cardHtml`/`select` 150-160, 630-650).

**Interaction/state:** drag orbit, wheel zoom, auto-rotate, text
search with jump-to, click-select side panel with neighbor count,
focus dimming, per-kind chips and per-state legend filters, hash
deep-links `#tab-graph/n=<id>`, Esc clears. v5 preserves the whole
operator view across the 60s reload: camera (grow-only distance),
selection, filters, search, spin (`snapshotView`/`restoreView`
238-248, applied in `load()` 720-799).

**Conventions worth copying:** owned `<style>` tag with `gv-` prefix
injected at mount (style.css untouched); headless contract-test seams
as pure functions (`layout.checkInvariants` 198-218,
`snapshotView._isFirstLoad` 249); `esc()` HTML-escape helper; error
banner with retry hint on feed failure; summary line into
`#graph-sum` ("N nodes · M edges · K alerting · mode 3D"). Header
comment is explicit: display layer only, never governance input.

## story-view.js — today-only narrative over ledger + plan feeds

**Data sources (both fetched per refresh):**
1. `plans.json` (built by `jobs/plan-feed.py`) — plan slugs, status,
   priority, steps (n/title/done), edges, `cause`, `generated` stamp.
2. `reports.md` — the report-queue ledger, served via the committed
   **symlink** `automation/dashboard/reports.md ->
   ../../docs/project/reports.md`, so it is always live with the
   kernel ledger (rp-mirror.md; no copy lag, no refresh job).

Fetched sequentially with local `fetchText(url, 8s)` (31-41, same
AbortController/`no-store` pattern), then `renderAll` (266-281).
Manual `#refresh-btn` + one automatic `refresh()` on page load; no
polling (contrast with graph's 60s HnghPoll).

**"Today" semantics (binding honesty rule):** `todayFromStamp()`
(53-57) takes the UTC date from the feed's own `generated` stamp —
never a client-side `Date`. If the stamp is unreadable the page fails
closed with the `#storyerr` banner ("failing closed instead of
rendering the wrong day", 272-274) and renders nothing.

**Ledger slicing:** `todayRows()` (61-67) filters reports.md lines by
prefix `| YYYY-MM-DD T` — i.e. a *date-window slice of the pipe-table
ledger* is already implemented, hardcoded to the single day "today".
`rowParts()` (69-71) splits pipe cells. Alert rows are
`rowParts(row)[1] === 'alert'` (204-206).

**Render approach:** pure innerHTML string building into pre-declared
section body ids (`sec-accepted-body`, `sec-steps-body`,
`sec-blockers-body`, `sec-parks-body` via `setBody()` 103-107). No
canvas, no virtual DOM. Sections: accepted/executing plans; chapters
= plans named in today's rows or accepted with open steps, high
priority first (`chaptersFor` 93-101); blockers from real edges only
plus today's alert rows; parks with `parked-because` causes quoted
verbatim from front matter.

**Honesty rules (project-wide, docs/design/presentation-direction.md):**
footnote hashes come ONLY from real hex tokens in today's rows
(`HEX` regex + `hashesFor()` 17, 75-89) — plus a ceremony branch
taking `feed.last_ceremony_commit`, though both current call sites
pass `null`/`{}` so the ceremony footnote is defined but not currently
wired (renderAccepted passes `{}` at 165, renderSteps passes `null` at
193, despite the steps aside claiming "the ceremony commit only in
the accepted section"). Missing facts render dim placeholders
(`dim()` 24-26, "(not recorded)"), never fabricated values. One dry
aside per section max (`MAX_ASIDE = 1`).

**Overflow idiom:** hard caps per section — 30 accepted, 20 chapters,
12 blockers, 15 alerts, 40 parks — each with a trailing
"(N of M shown)" dim line (164-168, 195-197, 217-221, 259-261).

## What a history view must NOT re-build (reuse/differentiate)

1. **Ledger row parsing.** `todayRows` prefix-match + `rowParts`
   pipe-split (story-view 61-71) is the existing reports.md row
   decoder; a multi-day history view should generalize this date
   window, not re-implement parsing. app.js's queue widget
   (app.js:338-383, per rp-mirror.md) also parses reports.md +
   report-cursor for the *unread* queue — a history view must
   differentiate from that widget and respect report-cursor's
   read/unread boundary rather than re-deriving it.
2. **Hex-evidence footnotes.** `HEX` + `hashesFor` (story-view 17,
   75-89) already extract commit hashes from rows with why/at
   metadata.
3. **fetch/esc helpers.** `fetchJson`(10s)/`fetchText`(8s) abort
   helpers are duplicated per file (graph-view 63-73, story-view
   31-41, app.js 330-336) — follow the same pattern or centralize;
   `esc()` is likewise duplicated in both.
4. **Polling.** Use the shared `window.HnghPoll` (interval override,
   tab-visibility gating, browser-hidden pause) if auto-refresh is
   wanted — never a raw timer (graph-view v3 rule).
5. **Staleness display.** The graph's data-age badge pattern
   (`tickBadge`) covers "feed freshness"; recency thresholds (2h/10min
   staleness, 24h patrol lookback) live in graph-data.py, not the
   view — a history view should likewise keep windows in the payload
   builder, not the client.
6. **Fail-closed conventions.** Literal error-banner id kept for the
   contract test ("storyerr" in story.html), dim placeholders for
   missing facts, cap + "(N of M shown)" overflow markers, evidence-
   only footnotes, no client-side dates — all are established
   patterns a history view should inherit as-is.
7. **Adjacent renderers already own other history surfaces:**
   sessions-view.js renders conversation history from sessions.json
   `detail.entries` (viz-history-payload.md); gantt.js renders
   schedule time bars; overview-view.js consumes /telemetry.json
   24h aggregate. A timeline/history view overlaps gantt (time axis)
   and sessions-view (event streams) — check those before adding any
   time-series rendering.
8. **Headless test seams.** graph-view exposes pure helpers
   (`layout.checkInvariants`, `snapshotView._isFirstLoad`) executed
   via node in contract tests; story-view keeps a literal banner id.
   A new history view should expect the same: pure no-DOM helpers for
   its date-window/filter logic so tests can drive them headlessly.
