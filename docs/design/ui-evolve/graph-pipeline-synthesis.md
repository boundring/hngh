# 2026-09-15 — retry-viz-render synthesis: render pipeline stage map integrated

Synthesis node for the retry wave (openrouter leg; originals failed on
zai/kimi endpoint outages). Original brief: read `jobs/graph-data.py`
output shape, the `graph-view.js` render loop, and define/prototype the
render pipeline stage (data -> scene graph -> canvas draw) with the
two-shell layout and 60s refresh wiring. Deliverable: pipeline stage map
plus working code path or explicit blocker report.

**Verdict: delivered and verified. The pipeline is a working code path,
not a prototype; the authoritative stage map with resolutions lives in
`docs/design/ui-evolve/graph-pipeline-stage-map.md` (5c54428d + 61b00655).
No blocker remains in scope.**

## Integrated result (one paragraph)

The megastructure viz is a demand-driven immediate-mode pipeline with 8
stages: S1 transport (fetchJson, 10s abort, no-store) -> S2 parse (gap:
only empty-graph check, recorded) -> S3 scene build (two-shell fibonacci
layout R=190 / R2=190+34*(n-1)^0.42, grow-only preallocated Float32
screen buffers, Int32 edge tables with -1 danglers skipped) -> S4 scene
query (pure predicates) -> S5 projection (orbit+perspective, zero
allocation) -> S6 draw (edge pass then painter's node pass; SVG fallback
is a second DrawTarget over the same Scene) -> S7 interaction (mutates
camera/view state then redraws; picking reuses last projection) -> S8
cadence (60s autoLoad, hidden-tab-gated via HnghPoll + #p-graph check;
5s badge; optional rAF spin). S3's Scene is the only coupling between
data and rendering; preserving that invariant is the rule for any
refactor (proposed modules gv-feed/gv-scene/gv-project/gv-draw/
gv-interact/gv-view).

## Feed and viewer contract, cross-checked

- Wire: `{generated_at, nodes, edges}`; node
  `{id,kind,label,state,detail}`; edge `{src,dst,rel}`; 13 kinds, 14
  relations, states healthy|stale|alerting|neutral. Served by
  `dashboard-server.py` graph_feed: dual 30s TTL cache slots (default vs
  `?all-sessions=1`), fail-soft last-good, cold-start fail-closed.
- Live scale this session: ~551 default / ~569 all-sessions nodes;
  two-shell pitch stays above dot size at the default camera, so no
  occlusion; jcode-session density is absorbed sublinearly.

## Node inventory landed by this wave (commits verified by the gate)

- 5c54428d stage map; 61b00655 open-question resolutions (7/7 dispositioned)
- b0b727f2 two-shell layout (v4) + contract tests + record
- 98011a4b surface-node dedupe + regression test (red-green proven)
- 8ce714d2 land untracked test-viz-schema-history.py (Makefile-required)
- 30966c38 + 2cb17877 loop-history 526cd3f exemption cure (kernel lane)
- 334a4934 sg camera-preserve v5 viewer + session shadow-dedupe + suite
  repairs + grade docs (the six dirty automation files)
- 6404d3dc (this synthesis) the two record files:
  `2026-09-15-graph-60s-refresh-wiring-plan.md`,
  `2026-09-14-sg-session-detail-exposure-decision.md`

## Verification at synthesis time (re-run on committed tree)

- node --check graph-view.js OK; py_compile on builder + 3 suites OK
- test-graph-data.py 23/23, test-dashboard-p0.py 22/22,
  test-graph-feed-refresh.py 8/8, test-viz-schema-history.py 16/16
- Gate had additionally passed make -C automation test (ALL PASS, lint
  clean) and root make test (2894 checks, 0 guard violations)

## Deliberate non-goals (accepted, out of lane)

- No live browser render check: kernel boundary forbids starting the
  dashboard server from machine sessions; all viz nodes verified via
  contract tests and headless probes. Accepted by the gate.
- S2 validator hardening (unknown-kind NaN radius via KIND_SIZE) is
  recorded in the stage map as the next refactor step, not a defect in
  the shipped feed (ids are deduped, dangling edges skipped).

## Follow-ups routed to the coordinator (non-blocking)

1. All-sessions UI toggle: server slot + tests exist, no owner; future
   home named as gv-feed (S1 owns the request URL).
2. Runtime browser render witness remains unproven (needs the
   grade-interface witness lane or operator).
3. Stale patch-id 4496b336 provenance (526cd3f registration) unresolved;
   harmless now that the correct id 5b6840df... is registered.
4. If outer-shell hub overlap becomes visible, kind-level clustering on
   the outer shell is the recorded next step (per the two-shell record).
