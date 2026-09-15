# 2026-09-15 — 60s graph refresh wiring: cross-slice plan (verification record)

Deep-task node `viz-refresh-wiring`. Task: find the sg-* jobs/children,
document the refresh trigger, interval wiring, and error handling for the
60s graph auto-refresh, and deliver a wiring plan or working code.

**Verdict: working code, already landed by the sg-* siblings in the
2026-09-14 working tree. This node verified the assembled chain end to
end and documents it in one place. No production code changed here.**

## The sg-* children and their share

| Node | Deliverable | Surface |
|---|---|---|
| `sg-builder-sessions` | jcode-session/swarm nodes in the builder feed | `automation/jobs/graph-data.py` |
| `sg-refresh-wiring` | `/graph.json` server path: TTL cache, fail-soft, pass-through, `?all-sessions=1` slot split | `automation/dashboard-server.py` |
| `sg-viewer-rendering` | client viewer + `POLL_MS = 60000` auto-refresh through the shared poll helper | `automation/dashboard/graph-view.js` |
| `sg-load-camera-preserve` | snapshot/restore of camera, selection, filters, search, spin across the 60s reload | `automation/dashboard/graph-view.js` |
| `sg-layout-density` | two-shell layout so session swarms don't crowd kernel nodes | `automation/dashboard/graph-view.js` |
| `sg-detail` (retry) | metadata-only exposure decision for session nodes | record only |

## Refresh trigger

Two-level visibility gate, both present:

1. **Tab visible** — `window.HnghPoll` (app.js:23-45) registers a
   `visibilitychange` listener; the timer is cleared while
   `document.hidden` and fires immediately on re-visible. 
2. **Graph tab active** — `graphTabVisible()` (graph-view.js:716-719)
   checks `#p-graph` not hidden; `autoLoad` (graph-view.js:720-722)
   fetches only when the graph tab is the mounted one. Other tabs never
   pay the /graph.json fetch cost.

So the trigger is: poll tick AND tab visible AND graph tab mounted.

## Interval wiring

- Client cadence: `POLL_MS = 60000`
  (graph-view.js:224), wired at mount:
  `pollTimer = window.HnghPoll.start(autoLoad, { interval: POLL_MS })`
  (graph-view.js:383).
- Shared helper contract (app.js:23-45): setTimeout chain (not
  setInterval, so a slow fetch never overlaps the next tick), first tick
  immediate, exponential backoff on failure (interval x2, cap 60s),
  reset on success. The graph poll is independent of app.js's core
  REFRESH_MS poll (app.js:754, 956).
- Server cache: `graph_feed()` (dashboard-server.py:321-342) caches per
  slot for `TELEMETRY_TTL_S` (30s), half the client cadence, so a poll
  always gets a fresh-ish payload; the effective worst-case data age is
  60s (client) + 30s (server TTL).
- First load: init does not fetch separately; the poll's first immediate
  tick performs the initial load (graph-view.js:817-820).

## Error handling

- Client fetch: `fetchJson` (graph-view.js:65-67) uses `cache: 'no-store'`
  with a 10s AbortController timeout. A rejection re-schedules with
  backoff (helper contract) and never overlaps ticks.
- Client render: `load()`'s `.catch` (graph-view.js:793-800) shows
  `.gv-err` ("graph feed unavailable … retry with the refresh button"),
  sets the badge to `feed error`, and the previous graph stays on
  screen. Camera/selection/filters are untouched on failure.
- Server: `graph_feed()` fail-soft to the last good graph (200) when the
  builder raises mid-flight; cold-start failure fails closed (500).
  The two slots (default vs `?all-sessions=1`) are independent: a wide
  fetch can neither serve from nor poison the default feed.
- State degradation, not data loss: badge drops `fresh`, summary row
  keeps its last good counts.

## Chain (one line per hop)

`POLL_MS=60s tick` → `graphTabVisible()` guard → `fetchJson('/graph.json', 10s timeout)` → `dashboard-server.py:402-406` route → `graph_feed()` 30s TTL cache slot → `graph_data.build()` → fail-soft last-good or fail-closed 500 → client `.catch` badge+banner, backoff re-poll.

## Validation

- `python3 tests/test-graph-feed-refresh.py` — 8 OK (server refresh
  path: TTL, fail-soft, pass-through, all-sessions slot split).
- `python3 tests/test-dashboard-p0.py` — 22 OK (includes
  GraphViewVocabularyAndAutoRefresh: POLL_MS=60000, helper reuse,
  hidden-panel skip; GraphCameraPreserve: view state survives refresh).

## Deliberately not here

- No websocket/SSE push channel; 60s pull is the accepted cadence
  (server cache is 30s; nothing in the feed changes faster than
  minutes).
- No `all-sessions` toggle in the viewer yet: the extended feed has a
  server slot and test coverage but no UI switch wires it to a fetch.
  Recorded as the open thread for a follow-up node.
- No mutation of any sg-* slice's code; this is the verification and
  documentation pass only.
