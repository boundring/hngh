# 2026-09-01 — arbitrary-request scheduling design

Status: DESIGN
Date: 2026-09-01

## Scope

Design how an operator, an alert, or a plan files a "request" that the
continuous queue picks up immediately or on a named cycle. Map intake onto
`queue.md` rotation, the plans contract, cadence-continuum tiers, and the
minimal-DelegationQueue line from `docs/research/2026-08-30-delegation-lane-
parallelism-multi-lane-omp-bridge-sessions-and-queueing.md`.

## Intake surfaces

### 1. Operator direct request

- Format: `docs/project/queue.md` row with `intent=request`, `priority=immediate`
  or `priority=cycle:<tier>`.
- The overnight cycle (single-lane consumer per `2026-08-30-delegation-lane-
  parallelism-*.md`) picks up `queued` rows on its next tick.
- Operator writes to `docs/project/queue.md` directly; the machine reads on
  tick.

### 2. Alert-triggered request

- An alert row in `docs/project/reports.md` (e.g. "SMTP config missing") can
  include `intent=request` and `priority=immediate`.
- The router (`scripts/router-tick.py`) already routes alerts to plan
  candidates; this extends the pattern — an alert can also file a request
  directly without going through plan acceptance.

### 3. Plan as request

- A plan file (`docs/project/plans/<date>-<slug>.plan.md`) is auto-accepted
  and executed per the plans contract (`docs/project/plans/README.md`).
- This is the heaviest intake surface; use for multi-step work.

## Execution mapping

- **Immediate**: `priority=immediate` rows execute on the next overnight cycle
  tick (every 20 minutes per `cadence/20-workbeat.sh`).
- **Cycled**: `priority=cycle:<tier>` rows execute on the named tier's tick
  (e.g. `cycle:day` runs on the daily cadence).
- **Queued**: rows without priority sit in `queued` state until picked up.

## Boundaries

- **Machine-owned**: `docs/journal/`, `docs/project/reports.md`,
  `docs/project/ui-grades.md`, `docs/design/ui-evolve/current-overlay.json`,
  `.omp/`, untracked routed plans, untracked research docs. The machine
  updates these directly without ceremony.
- **Ceremony-gated**: hngh docs changes land via certificate ceremony with
  green `make test`.
- **Forbidden**: hngh kernel `src/`, `tests/`, `Makefile`, `hngh.asd` changes
  — park with alert rows.

## Next steps

- Document the queue.md row format (intent, priority, state transitions).
- Wire alert-triggered requests into the router.
- Test the immediate/cycle priority routing.

## Sources

- docs/project/queue.md (rotation state)
- docs/project/plans/README.md (plans contract)
- docs/project/backlog.md (cadence-continuum, activity-cadence rows)
- docs/research/2026-08-30-delegation-lane-parallelism-*.md (DelegationQueue,
  overnight cycle as single-lane consumer)
- scripts/router-tick.py (alert routing)
- cadence/20-workbeat.sh (tick cadence)
