<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-10 — bench trigger lane: event-driven benchmarking

Operator directive 2026-09-10: local benchmarks become occasional and
event-driven, not nightly. Design:
docs/design/bench-triggering.md. Triggers: (a) new model in the
tracked fleet list, (b) recalibration drift (monthly, top model +
demoted-model evidence re-check). The nightly timer and the
10-bench-fresh full-fleet catch-up retire via this lane's steps.

## Steps

- [ ] 1. Bench-trigger state + diff probe (test-first). New
      automation/jobs/bench-trigger.sh with two verbs:
      `new-model-check` (diff config.env BENCH_MODELS +
      UNSLOTH_FALLBACK_MODELS against the union of models in
      stats/model-bench-*.jsonl; an unbenched name -> run
      `BENCH_MODELS=<name> jobs/model-bench.sh` scoped, file an
      operator-item with the ranking delta) and `recalibrate-check`
      (cadence-params row benchmark-recalibrate-days, default 30; when
      the newest digest is older than the row: re-bench the current
      top model from the digest and any demoted-not-cleared model from
      automation/state/model-demote.tsv, feeding the result through
      record_model_outcome). Guardrail in both verbs: read
      failfirst-development state and budget.md - defer (breadcrumb,
      no bench) when speed is active and a session ran in the last
      30 minutes. Suite test first: sandbox config stub, fake digest,
      fake state - covers unbenched-name fires scoped bench (assert
      BENCH_MODELS passed as one model), no-op when diff empty,
      recalibrate fires on stale digest only, quiet-guard defers.
      Verification: suite test covers new-model fire, no-op diff,
      recalibrate-stale-fire, quiet-guard defer; full `make test`
      green.
- [ ] 2. Mount the week-tier drop-in + params row. New
      automation/cadence/week/02-bench-trigger.sh running both verbs
      (week tier exists: cadence/week/); add
      `benchmark-recalibrate-days  30  docs/design/bench-triggering.md`
      to cadence-params.tsv. Suite test mounts nothing real but
      asserts the drop-in sources the same verbs and the params row
      parses (get_param).
      Verification: week tick breadcrumb shows 02-bench-trigger
      mounted and both verbs evaluated (dry breadcrumb); params row
      read via get_param; `make test` green.
- [ ] 3. Retire the nightly schedule. Route for the director: disable
      `hngh-model-bench.timer` (operator-authorized systemd lifecycle
      change - operator directive 2026-09-10 names this exact unit)
      and remove the full-fleet catch-up from
      cadence/day/10-bench-fresh.sh (replace with a breadcrumb-only
      staleness note feeding the recalibrate verb). Update
      cadence-params.tsv `benchmarking-backburner` row note to point
      at this plan. The week-tier verbs are the only bench path after
      this step.
      Verification: timer shows disabled (director-executed,
      evidence row in reports.md); no cadence drop-in invokes the
      full fleet on a schedule; `make test` green.

## Execution notes

- Step 1 is self-contained; 2 depends on 1; 3 depends on 2 (the
  disable must not precede the replacement path).
- The bench script itself needs no changes for the scoped run:
  BENCH_MODELS is already environment-parametrizable (config.env
  default).
- Voice check: design doc has one epigraph, no exclamation marks.
