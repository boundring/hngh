# fail-20260910-overnight-plan-accept-blocked-2026-09-09-stall-recovery-and-operator-surfaces

## Question

Why did plan 2026-09-09-stall-recovery-and-operator-surfaces fail auto-accept
twice with "step 1 has no Verification line", and is the acceptance blocker
still open or already resolved?

## Evidence read

- Routed plan docs/project/plans/2026-09-10-routed-overnight-plan-accept-
  blocked-2026-09-09-stall-recovery-and-operator-surfaces.plan.md: routed by
  scripts/router-tick.py at 2026-09-10T01:00:18Z from alert identity
  `overnight:plan-accept-blocked:2026-09-09-stall-recovery-and-operator-
  surfaces`; alert text "not auto-accepted: step 1 has no Verification line
  x2"; re-occurred 02:00Z and 03:00Z (dedup window expired), then no further
  occurrences.
- automation/scripts/accept-plans.py:35 defines `VERIFICATION` (a step is
  runnable only when it carries a `Verification:` line);
  automation/scripts/accept-plans.py:344-346 files the alert with that exact
  identity and an 86400 s dedup when `first_unverified_step()` finds an
  unchecked step without one. The x2 in the alert text is the occurrence
  count accumulated before the dedup window, not two distinct plans.
- Kernel plan docs/project/plans/2026-09-09-stall-recovery-and-operator-
  surfaces.plan.md header: `status=accepted accepted=2026-09-09T15:01:13Z` —
  the plan was accepted ~10 h BEFORE the alert routed (the alert was filed
  against the pre-fix draft, sat in the unread ledger, and the router tick
  routed it regardless of the later acceptance).
- Same plan, step 1: checked `[x]`, AUDIT-CLOSED 2026-09-13T18:40Z with
  provenance "automation/tests/test-model-demote.sh runs ALL PASS (11
  cases ... mirroring the plan's verification wording)". Every still-unchecked
  step (7-11) carries an explicit `Verification:` line, so the acceptance
  gate would pass the plan today without complaint.

## Doctrine applied

- Obsolete-state lesson (automation/state/ocgo-agent-lessons.md, repeated
  obsolete rows 2026-09-12..14): check current ledger state before acting on
  anything read earlier — the routed Delve sat 4 days while sibling sessions
  executed the underlying plan.
- Precision-first acceptance gate: unknown/missing verification fails closed
  (accept-plans.py refuses the plan rather than accepting a non-runnable
  step) — the gate behaved as designed; no guardrail gap.

## Findings

1. Root cause: the pre-acceptance draft of step 1 of
   2026-09-09-stall-recovery-and-operator-surfaces lacked a `Verification:`
   line; accept-plans.py:344-346 correctly refused auto-accept and filed the
   alert (twice, dedup window 86400 s).
2. The blocker is already resolved upstream: the plan was accepted at
   2026-09-09T15:01:13Z, and step 1 was executed and audit-closed
   2026-09-13T18:40Z with test-model-demote.sh 11/11 PASS. The alert was
   stale by the time it routed; it has not re-occurred since 2026-09-10T03Z.
3. Disposition: killed — resolved before research. No fix or park action
   remains; the acceptance gate itself needs no change.

## Recommended next line

None. The routed plan's remaining work is bookkeeping only: this record, the
research-subjects.txt row, the research-dispositions.tsv disposition row, and
the routed plan's step tick.
