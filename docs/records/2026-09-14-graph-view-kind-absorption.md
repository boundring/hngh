# 2026-09-14 — graph-view absorbs jcode-session/swarm kinds + 60s tab-visible auto-refresh

Deep-task-graph node `sg-viewer-rendering` (work-graph rung: viewer
rendering vocabulary). Task: absorb the two new graph node kinds into
`automation/dashboard/graph-view.js` with zero logic change elsewhere,
plus an optional cheap auto-load. The feed-side emitter change is a
sibling node's scope; this record covers the viewer only.

## What landed

- **Vocabulary** (`automation/dashboard/graph-view.js`): KIND_SIZE gains
  `'jcode-session': 4` and `'swarm': 6`; KINDS (the chip/legend filter
  vocabulary) gains both names, so nodes of these kinds render at their
  size and appear as visibility chips with counts (buildChips filters
  chips to kinds actually present in the feed, so no empty chips until
  the producer emits them). COLORS and STATES stay state-keyed and
  untouched: the 4-state vocabulary (healthy/stale/alerting/neutral) is
  reused unchanged. parseDetail's 12 k=v pair cap unchanged.
- **Auto-load**: the graph tab now auto-refreshes /graph.json every 60s
  through the shared `window.HnghPoll` helper (interval override — no
  second timer, no raw setInterval; `pollTimer` holds the handle in the
  sessions-view pattern). The fetch is gated on panel visibility
  (`graphTabVisible()` checks `#p-graph.hidden`, the same panel state
  app.js toggles per tab): a parked dashboard tab (another tab in front)
  skips the fetch entirely and just re-checks next tick. HnghPoll
  already pauses the whole timer while the browser tab itself is hidden,
  and backs off exponentially on feed errors (60s cap). The poll's
  immediate first tick now performs the initial load, replacing the
  old direct `load()` call in init.

## Contract tests

`automation/tests/test-dashboard-p0.py` gained
`GraphViewVocabularyAndAutoRefresh` (textual contract on the served
source, the suite's established discipline): both kinds present in
KIND_SIZE and KINDS, STATES byte-unchanged, auto-refresh via
`HnghPoll.start(autoLoad, { interval: POLL_MS })` with `POLL_MS =
60000`, no raw timers, and the visibility gate ordered before the
fetch. All 17 p0 tests pass; p1, p1-ui, and plan-feed-graph suites
pass. `test-graph-data.py` has a pre-existing failure at HEAD
(`test_view_registered_in_shell` still expects the deleted
`vendor/three.min.js`) plus build errors from another agent's
in-flight edits — out of this slice's scope.

## Honest gaps

- The two kinds are not yet emitted by `automation/jobs/graph-data.py`
  (sibling node): viewer renders them when the feed starts carrying
  them. Until then the chips are latent.
- Verification is textual + syntax-level (`node --check`); no browser
  run with a feed actually carrying jcode-session/swarm nodes was done
  (the producer does not emit them yet), so rendered-chip behavior for
  the new kinds is asserted by contract, not observed live.
- The `rel` field on edges remains ignored by the renderer, per the
  schema contract and no record saying otherwise.
