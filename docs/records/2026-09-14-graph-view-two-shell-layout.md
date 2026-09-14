# 2026-09-14 — Graph viewer two-shell layout (density mitigation)

Deep-task node `sg-layout-density` (viewer-side fallback after
`sg-builder-sessions` landed the 24h cap). Evaluation first, change only
if warranted.

## Evaluation: mitigation is warranted

The task allowed a "no change needed" outcome if the 24h cap kept the
default graph near ~30 nodes. It does not. The real default feed
(graph-data.build with default args, 2026-09-14) carries:

- 351 nodes total: 124 `jcode-session` + 1 `swarm` + 226 kernel-side
  (the 24h cap did trim 291 files to 124 session nodes, but the feed was
  never ~30 nodes to begin with — kernel-side is 226 on its own)
- old layout: every node on one fibonacci sphere of R=190 →
  average nearest-pitch ~36 world units, and the measured minimum
  pairwise distance on the real feed was 14.4 world units — below the
  on-screen diameter of a `jcode-session` dot (~23 world units at the
  default camera), so dots occluded each other

Crowding is real and viewer-side mitigation follows the task's stated
preference.

## Change: kind-aware secondary shell (small, reversible)

`automation/dashboard/graph-view.js` only (display layer; feed contract
untouched):

1. Two-shell layout: `jcode-session` and `swarm` nodes move to a
   secondary outer fibonacci sphere whose radius grows sublinearly with
   their count (`R2 = 190 + 34 * (count-1)^0.42`; 125 outer nodes →
   R2 ≈ 447.5, 2.4x the kernel shell). Kernel-side nodes keep the
   original single-shell layout and the kernel stays at the origin.
2. Camera default re-fit: `resetView()` sets
   `cam.r = max(640, shellRadius * 1.9)` so the outer shell fits on
   load and on the reset button (850 for today's feed; small feeds keep
   the old 640 view). Zoom clamps widened to match (480–4800).
3. SVG fallback (`?graph2d=1`) projection scale follows the outer shell
   instead of the fixed `/480` divisor, so the flat view also fits.

Node order in the feed is unchanged; the layout remains deterministic;
no layout library introduced. Reverting is a single-function plus
two one-line changes.

Guarantee for the "small feed" future: with no outer-kind nodes the
layout is byte-identical to the legacy algorithm (asserted by a
regression test that executes both over the same synthetic feed), so if
sessions ever drain away the mitigation degrades to a no-op.

## Verification

- `node --check automation/dashboard/graph-view.js`
- Headless execution of the extracted layout over the real 351-node
  feed (deduped for the run, see open questions): all nodes positioned,
  no NaN/Inf, kernel at origin, per-kind shell radii exact
  (190 / 447.5), min pairwise distance 14.4 → 31.4 world units (2.2x)
- Synthetic edge feeds: zero / one / 1000 outer nodes all pass the same
  invariants
- Regression tests added to `automation/tests/test-dashboard-p0.py`
  (`GraphTwoShellLayout`, 3 tests): textual contract on the served
  source (same discipline as the rest of the suite) plus real execution
  of the extracted function via a new `run_node` helper (skips when
  node is absent, like the dashboard quarantine skip): invariants on a
  synthetic two-shell feed, and byte-identical legacy match for a
  no-session feed
- `make -C automation test` full gate: ALL PASS, identifier lint clean
- Dashboard suites: p0 20/20, p1 23, p1-ui 13, plan-feed-graph 5,
  graph-feed-refresh 8 — all green

## What this deliberately does not do

- No clustering/force layout, no layout library, no kernel-side
  positioning changes
- No feed schema change; the viewer still ignores `rel` on edges
- No claim of rendered visual quality: verification is headless
  execution plus numeric density metrics; a real-browser look at the
  rendered density is left to the grade-interface witness lane

## Open questions (out of this node's scope)

- The live feed emits two `surface` nodes twice (`surface:kernel-gate`,
  `surface:services`; identical content) — a pre-existing
  `graph-data.py` builder quirk, harmless in render (deterministic
  last-write), but the builder should dedupe. The new invariant hook
  caught it; surface dedupe belongs to a builder-side node.
- If session counts grow past ~1000, the sublinear outer radius keeps
  pitch roughly constant; kind-level clustering (sessions near their
  `spawns`/`coordinates` hubs) would be the next step if hubs start
  overlapping on the outer shell.
