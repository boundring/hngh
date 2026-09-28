# 2026-09-27 — governed-fleet blocker triage (blk-20260927)

## Evidence
- Three consecutive overnight executor deaths, all rc=124 (timeout), on plan
  `2026-09-13-governed-fleet-consolidation|run-1`:
  - `automation/agent-handoffs.md:1061` — 2026-09-27T12:32:40Z, cause=obsolete
  - `automation/agent-handoffs.md:1312` — 2026-09-27T17:37:37Z, cause=bad-execution
  - `automation/agent-handoffs.md:1361` — 2026-09-27T22:31:43Z, cause=bad-execution
- Log tails show mid-work kills at the executor's own `TIMEOUT_S=1800` ceiling
  (`automation/scripts/overnight-cycle.sh` ~L60), each mid-slice.

## Root cause
Budget vs step size, not a lane defect: plan Slice C was a single unchecked step
requiring live multi-minute waits (launch hero session, wait for a 5m subhour
tick, observe supervision/respawn, then run kernel `make test`). It cannot fit
inside 1800s, so every attempt re-died and was re-parked as bad-execution.

## Fix
1. Split Slice C into C1/C2/C3 sub-entries, each completable inside 1800s
   (`docs/project/plans/2026-09-13-governed-fleet-consolidation.plan.md`).
   `TIMEOUT_S` left untouched — the split is the fix.
2. Deleted the parked blocker row `blk-20260927-2026-09-13-governed-fleet-consolidation`
   from `automation/state/beat-blockers.tsv` (ledger self-clears on next ok;
   deleting re-admits the plan immediately).
3. The partial slice-C work (agent-respawn `sessions-day-max` read from params)
   was already committed as `958c1949` (verified via
   `git log --oneline -1 -- automation/jobs/agent-respawn.sh`); file not re-edited.

## Scope note
This lane is orchestration-only: zero pacman/sudo/package surface — not on the
omarchy critical path.
