<!-- plan: status=executed risk=normal accepted=2026-09-10T14:01:06Z -->
# 2026-09-10 — bench trigger lane: event-driven benchmarking

Operator directive 2026-09-10: local benchmarks become occasional and
event-driven, not nightly. Design:
docs/design/bench-triggering.md. Triggers: (a) new model in the
tracked fleet list, (b) recalibration drift (monthly, top model +
demoted-model evidence re-check). The nightly timer and the
10-bench-fresh full-fleet catch-up retire via this lane's steps.

## Steps

- [x] 1. Bench-trigger state + diff probe (test-first). New
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
- [x] 2. Mount the week-tier drop-in + params row. New
      automation/cadence/week/02-bench-trigger.sh running both verbs
      (week tier exists: cadence/week/); add
      `benchmark-recalibrate-days  30  docs/design/bench-triggering.md`
      to cadence-params.tsv. Suite test mounts nothing real but
      asserts the drop-in sources the same verbs and the params row
      parses (get_param).
      Verification: week tick breadcrumb shows 02-bench-trigger
      mounted and both verbs evaluated (dry breadcrumb); params row
      read via get_param; `make test` green.
- [x] 3. Retire the nightly schedule. Route for the director: disable
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
- 2026-09-14T04:45Z machine session: step 3 machine-doable work verified
  landed in 26cf873 (10-bench-fresh.sh is a staleness note only,
  benchmarking-backburner row points at this plan, no cadence drop-in
  invokes the full fleet on a schedule; automation make test green).
  Remaining loop is director-only: systemctl --user disable --now
  hngh-model-bench.timer (unit verified still enabled+active at
  04:39Z; alert 4e63a558 live, router already spawned plan candidate
  2026-09-14-routed-bench-lane-timer-disable). Step 3 stays unchecked
  until the disable has its evidence row in reports.md. Plan-file
  commit itself is blocked this session: kernel gate red on
  test-fleet-manager/tailscale environment skew (mesh up asserts
  logged-out) - candidate staged, not committed.
- 2026-09-14T05:12Z wake: steps 1-2 verified and TICKED. Suite
  tests/test-bench-trigger.sh ALL PASS (new-model fire, no-op diff,
  recalibrate stale-fire, quiet-guard defer, day drop-in retired/note-only);
  week-tier breadcrumb is live evidence for step 2 (STATE.md 03:04:07Z:
  02-bench-trigger mounted, bench-new-model no-op "config fleet fully
  benched", bench-recalibrate fresh "BENCH-2026-09-13.md 78638s < 30d");
  params rows benchmark-recalibrate-days=30 and row-51 note verified.
  Docs-only plan tick is a plain docs commit, not ceremony-gated (2a5c371
  precedent; ceremony covers kernel code surface only). Step 3 stays
  unchecked: hngh-model-bench.timer re-verified enabled+active 05:07Z;
  director-routed plan 2026-09-14-routed-bench-lane-timer-disable carries
  the disable; alert 4e63a558 stands.
- 2026-09-14T08:38Z wake: step 3 sweep ran live-surface verification.
  Live systemctl: hngh-model-bench.timer verified enabled+active
  twice this wake; reports.md carries only alert 4e63a558, so the
  evidence row is still missing - step 3 stays UNCHECKED, no
  fabrication (dream check 3). No duplicate routing:
  2026-09-14-routed-bench-lane-timer-disable carries the disable
  (status=proposed; do not re-file, dream check 4).
  Verified landed machine-doable portion: 26cf873, day drop-in
  10-bench-fresh.sh is note-only and executed live at 08:37:24Z
  (breadcrumb: staleness note, newest bench 12228s old), never redone.
  Post-disable sweep (PENDING comment update + step-3 tick + evidence
  row) runs the session after live systemctl shows disabled+inactive.
  Kernel-gate note: full-gate reds of the tailscale skew shape did not
  reproduce (lesson 08:12Z) — retry the full gate before staging mocks.
- 2026-09-17T10:12Z wake (dream-guided, guard-first): five live-state
  facts verified before any edit — (1) live systemctl: timer
  enabled+active (last fire 2026-09-17 01:10 EDT, next 2026-09-18
  01:10 EDT) -> Branch A hard no-op at the director boundary; (2)
  reports.md greps 0 hits for 4e63a558 — the 09-14 notes' "alert
  4e63a558 stands" assertion is stale (string absent from every
  ledger grepped this wake); the routed plan file itself still carries
  the disable, so the boundary stands on the plan text, not the alert
  string; (3) routed plan 2026-09-14-routed-bench-lane-timer-disable
  still status=proposed, not re-filed; (4) 10-bench-fresh.sh still
  note-only with PENDING (26cf873 holds, not redone); (5)
  cadence-params rows verified: 51 note points at this plan, row 60
  benchmark-recalibrate-days=30. Zero slice edits, zero re-filing.
  Step 3 stays UNCHECKED pending live disabled+inactive + evidence
  row in reports.md. Blocker blk-20260916-2026-09-10-bench-trigger-lane
  stands active (cause=unknown); counter-lesson held: live-state
  evidence outranked the 09-14 notes.
- 2026-09-19T17:15Z wake: step 3 COMPLETE, ticked. Live systemctl
  --user: hngh-model-bench.timer disabled+inactive (observed 17:06Z;
  journal has no disable-event entries, so observation-time state).
  Sweep landed in one pass (dream 2026-09-19T17:03Z guided): evidence
  row reports.md 90b82f24 (scripts/report-queue --add progress, not a
  hand edit); PENDING notes retired in cadence/day/10-bench-fresh.sh
  and cadence-params.tsv row 51 (stale 4e63a558/enabled+active claims
  dropped — 4e63a558 was already absent from reports.md, the 09-14
  notes were stale carriers); blocker blk-20260917-bench-trigger-lane
  cleared via lib/beat-blockers.sh blocker_clear; routed disable plan
  2026-09-14-routed-bench-lane-timer-disable (accepted
  2026-09-18T01:41:57Z) never re-filed. Verification: no cadence
  drop-in invokes the full fleet on a schedule (10-bench-fresh.sh is
  note-only, verified live 2026-09-19T14:24:49Z STATE.md row);
  automation make test green this wake. LANE COMPLETE — week-tier
  verbs are the only bench path.
