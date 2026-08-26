# Activity cadence slice — 2026-08-26

The `activity-cadence` autonomy-continuum rung (roadmap Next item 2,
backlog entry): routine project activities mapped to cadence tiers and
riding the existing cadence-continuum machinery, scaled to the fleet.

## Deliverables

### hngh kernel
- `docs/project/activity-matrix.md` — the matrix: each activity
  (roadmap review, planning, design, roadmap expansion, implementation,
  review, refactor, cleanup, inward comms, outward comms) mapped to a
  cadence tier, the existing artifact it advances, its smallest
  increment, and its skip condition (file a report instead of acting
  when the increment is undefined). All rows are adoptable-by-peer.
- `docs/project/reports.md` + `docs/project/report-bodies/` — a clean
  first report ledger produced by one pass of each mounted drop-in
  (the observable cadence evidence).
- `docs/project/queue.md` — one dated zoom-out pass-log entry (the
  zoom-out loop's documented append protocol).

### hngh-automation
- `cadence/day/01-activity-tick.sh` — day-tier: reads the matrix and
  performs-or-files the next increment of each day activity
  (implementation, review, refactor, cleanup, inward comms), each from
  a real bounded read of the artifact it advances; skip-condition
  reports when the increment is undefined; files an `owned-by <peer>`
  report for any row a fleet peer has adopted (display/ledger only,
  never a dispatch network).
- `cadence/week/01-roadmap-review.sh` — week-tier: roadmap-review,
  planning, and outward-comms increments from roadmap.md/queue.md.
- `cadence/month/01-zoom-out.sh` — month-tier: thin wrapper around the
  zoom-out-loop lane, appending a dated zoom-out pass-log entry (the
  documented protocol) and filing a report.
- `systemd/hngh-cadence-day.{service,timer}` — the missing `day` tier
  unit (cadence-continuum had mounted 1m/5m/10m/week/month but no day);
  `Makefile` `enable:`/`disable:` now includes it. Timer is NOT enabled
  (operator installs via `make enable`).
- `STATE.md` breadcrumbs — one full run of each tier recorded.

## Gates
- hngh `make test`: green (2774 lisp checks + all python files rc=0).
- hngh-automation `make test`: identifier lint clean.
- Each drop-in run once for real via `jobs/cadence-tick.sh TIER=...`
  (day, week, month), all rc=0 with breadcrumb + report-row evidence.

## Steering log (self-introspection ticks)
This slice folded in the ritualized minute-level check-in: after each
build/step, the next smallest correct step was decided from the actual
output before acting.
- Re-grounded anchors against the live tree before editing (cadence-continuum
  had landed only 1m/5m/10m/week/month; no `day` unit existed though
  cadence-tick accepts `day`) -> added the missing day unit.
- Read-only boundary honored: automation writes only the report ledger
  (config.env/security-check rule); "performing" an increment means
  filing a dated report derived from a real artifact read, never
  editing governed source. The one governed-file append is queue.md's
  dated zoom-out pass-log entry, which is the loop's documented
  protocol and non-authoritative.
- Review-increment read excluded its own kind to avoid self-reference.
- Zoom-out append made idempotent per day to avoid duplicate pass-log
  entries on re-run.
- Reset the report ledger and produced one clean representative pass of
  all three tiers after the repeated test runs had cluttered it.
- Adopted() path unit-checked in isolation against a scratch fleet.md
  before trusting it in the committed drop-in.

## Not in scope
`surface-evolution-loop`, `agent-live-view`, `machine-steered-backlog`,
`governance-vocabulary` remain queued (roadmap Next item 2). The
`surface-evolution-loop` backlog item (dancing-ui / grade-interface /
evolve-operative) is the next routine candidate after this lands.