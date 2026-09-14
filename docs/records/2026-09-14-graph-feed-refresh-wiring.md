# 2026-09-14 — graph feed refresh path: proof + all-sessions plumbing

Deep-task node `sg-refresh-wiring`. Scope: `automation/dashboard-server.py`
only — the `/graph.json` refresh path. `jobs/graph-data.py` (the builder)
and `dashboard/graph-view.js` (the renderer) were read but not touched.

## What the refresh path already did right (now proven by test)

`graph_feed()` cached the built graph for `TELEMETRY_TTL_S` (30s) and
failed soft to the last good graph when `graph_data.build()` raised. That
behavior is correct for session churn (churn is picked up on the next
build after TTL expiry; a registry hiccup mid-window never blanks the
view) — but nothing exercised it. The new
`automation/tests/test-graph-feed-refresh.py` proves it end-to-end over a
real `ThreadingHTTPServer` bound to an ephemeral localhost port per test
(no daemon, nothing left listening), with the builder seamed to a
recording stub and session-shaped fixture payloads:

- second GET within the 30s TTL serves the cached graph — the builder ran
  exactly once; after TTL expiry it rebuilds (test back-dates the cache
  timestamp, no real 30s sleep);
- when the builder raises after a good build, the endpoint still serves
  200 with the last good graph, byte-equal;
- a cold-start builder failure (no last good graph) fails closed — the
  request dies (client sees the dropped connection), no empty/partial
  graph is ever invented;
- unknown/new node kinds (`jcode-session`, `swarm`) pass through
  `/graph.json` unmodified — the server is a pass-through, kind
  filtering is the viewer's business, never the server's.

## What changed in the server (minimal interface closure)

- `GET /graph.json?all-sessions=1` now forwards the flag to the builder
  as `graph_data.build(..., all_sessions=1)`. Presence of the query
  param with value `1` is the switch; anything else (absent, `=0`,
  `=2`) is the default feed. The builder owns what the flag means.
- `_graph_cache` became two slots: default and `all-sessions`, so a wide
  fetch neither serves from nor extends the TTL of the default feed the
  other views consume. Slot count is bounded (2), not param-keyed — no
  unbounded cache growth from arbitrary query strings.
- Everything else (TTL value, fail-soft order, route shape) is unchanged.

## Tests run

- `python3 automation/tests/test-graph-feed-refresh.py` — new, 8 tests, OK
- `python3 automation/tests/test-graph-data.py` — 10/11 OK;
  `test_view_registered_in_shell` fails identically on the unmodified
  tree (stale `vendor/three.min.js` assertion vs the 2026-09-14 v2
  canvas rewrite of graph-view.js — pre-existing, outside this lane)
- `python3 automation/tests/test-dashboard-p0.py` — OK (14)
- `python3 automation/tests/test-dashboard-p1.py` — OK (23)
- `python3 automation/tests/test-dashboard-p1-ui.py` — OK (13)
- `python3 automation/tests/test-dashboard-feedback.py` — OK (13)
- `python3 automation/tests/test-dashboard-selfreview-ledger-skew.py` — OK (6)

## Not checked

- Real browser fetch of `/graph.json?all-sessions=1` (no consumer of the
  flag ships in this slice; graph-view.js untouched by mandate).
- The builder's own `all_sessions` behavior — `graph-data.py` does not
  accept the kwarg yet; forwarding it is the server-side half of the
  interface, landed so the builder can adopt it without a server change
  (a `TypeError` from today's builder would land in the fail-soft slot
  after a first good build, and is visible as the cold-start failure
  path until then).
- Keep-alive/multi-client concurrency beyond what the harness suites
  already exercise.
