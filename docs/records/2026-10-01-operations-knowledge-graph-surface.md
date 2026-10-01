# 2026-10-01 — operations knowledge-graph surface closure (slice G, governed fleet)

Triage for blocker `blk-20260930-2026-09-13-governed-fleet-consolidation`
plus closure of plan slice G
(`docs/project/plans/2026-09-13-governed-fleet-consolidation.plan.md`),
routed attempt 2
(`docs/project/plans/2026-10-01-routed-beat-parked-2026-09-13-governed-fleet-consolidation.plan.md`).

## Blocker triage (blk-20260930)

Evidence:

- `automation/state/beat-blockers.tsv` row `blk-20260930-...`, cause
  `bad-execution`, 2026-09-30T21:05:20Z (deleted this session after the
  disposition; the row is untracked runtime ledger, the 2026-09-27
  `docs/records/2026-09-27-fleet-blocker-triage.md` precedent).
- `automation/state/ocgo-agent-lessons.md` tail: the 2026-09-30T21:05:20Z
  lesson is the step-sizing class — "the step was too big or never
  verified: shrink the step and prove the thing works on its own
  surface before claiming done".
- Research ledger: subject `fail-20261001-beat-parked-2026-09-13-governed-fleet-consolidation`
  appended to `automation/research-subjects.txt` and the adopted
  9-column disposition row appended to
  `automation/research-dispositions.tsv` (automation commit `4c1c0d38`).

Root cause: step sizing, not a surface defect. Both deaths treated
slice G as a fresh full build; the surface was already landed 2026-09-14
(the sg commits below). Fix: the residue is a closure package sized to
one session — verify, record, flip the plan box, append evidence rows,
run both gates. Re-admission: the blocker row was deleted (deleting
re-admits immediately; the ledger self-clears on the next ok).

## What the landed surface is (verified this session, never rebuilt)

- Builder: `automation/jobs/graph-data.py` builds the operations graph
  from the section-2 registries (config/*.tsv), the telemetry db,
  service-state.json, reports.md, and jcode sessions; node kinds
  kernel, leg, service, package, seam, spawn-path, patrol, surface,
  cap, guard, research-line, jcode-session, swarm.
- Feed: `automation/dashboard-server.py` `GET /graph.json` — 30s
  fail-soft cache, two slots (default + `?all-sessions=1`), pass-through
  of unknown kinds (`docs/records/2026-09-14-graph-feed-refresh-wiring.md`).
- Viewer: `automation/dashboard/graph-view.js` v2-v5 — canvas-3D
  perspective (depth-sorted painter's algorithm, orbit, zoom,
  auto-rotate), per-kind chips, two-shell layout, camera-preserving 60s
  tab-visible auto-refresh, SVG fallback behind `?graph2d=1` (mode
  select at :315, `render2d` at :813). The WebGL/three.js path was
  retired by recorded divergence — graph-view.js v2 header: "the
  operator's daily-driver Chrome has WebGL dead
  (getContext('webgl') === null even on attached canvases)", so the
  three.js path could never run there; `vendor/three.min.js` was
  deleted. The broadsheet newspaper map keeps its own
  `vendor/three.module.min.js` import (`broadsheet-view.js:291`) — an
  unrelated surface, untouched.
- Shell wiring: `console.html` + `app.js` register the graph tab
  (`GraphView` into `#graph-root`).

Per-surface proofs (this session, 2026-10-01T01:1x–01:3xZ):

- `python3 -B automation/tests/test-graph-data.py` — 25 tests OK.
- `python3 -B automation/tests/test-plan-feed-graph.py` — 5 tests OK.
- `python3 -B automation/tests/test-graph-feed-refresh.py` — 8 tests
  OK; the mid-suite server-side traceback is the designed cold-start
  fail-closed case (builder raise, client sees the dropped connection,
  no empty graph invented).
- Live probes: `GET /graph.json` 200 (408 nodes / 401 edges / 11
  kinds), `GET /graph.json?all-sessions=1` 200, `GET /console.html` 200
  carrying the graph-view.js script and tab-graph wiring.

Surface commits (verified via `git log --follow` on
`automation/jobs/graph-data.py` and `automation/dashboard/graph-view.js`):
`5b48f69d`, `c1e016df`, `f93261a8`, `38b6c354`, `c507b197`, `f611a771`.
Per-increment records: `2026-09-14-graph-jcode-sessions.md`,
`2026-09-14-graph-view-kind-absorption.md`,
`2026-09-14-graph-view-two-shell-layout.md`,
`2026-09-19-light-graph-convention.md`.

## Makefile wiring decision

`tests/test-graph-feed-refresh.py` was proven 2026-09-14 but never
wired into the automation gate. Decision: WIRED this session (one line
next to `tests/test-graph-data.py`, `automation/Makefile`). The suite
is hermetic (ephemeral localhost port per test, nothing left
listening), ~3.5s standalone, and its fail-soft/fail-closed refresh
contract belongs in the standing gate. No silent gap.

## Assertion for this attempt (the blocker's countermeasure)

Closure package only: verify landed surfaces (tests + live probes),
record, flip the plan box, append evidence rows, run both make-test
gates — no rebuild, no kernel code surface
(src/tests/Makefile/hngh.asd untouched), named-path-only staging (the
2026-09-30 slice-D compound-command incident is the anti-pattern).
Slice G is operator-directed visibility and NOT exit-bearing: no
certificate loop, no roadmap stage-3 flip — that is the separate final
plan step with its own ten-invariants gate.

## Gates

- automation `make test` rc=0 (now includes
  `tests/test-graph-feed-refresh.py`).
- kernel `make test` rc=0 (2954-check baseline stands; kernel code
  surfaces untouched).
