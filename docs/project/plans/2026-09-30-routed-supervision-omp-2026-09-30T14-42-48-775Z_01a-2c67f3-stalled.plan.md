<!-- plan: status=accepted risk=normal accepted=2026-09-30T15:06:28Z routed-from=supervision:omp-2026-09-30T14-42-48-775Z_01a-2c67f3:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-07T15:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-09-30 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-2026-09-30T14-42-48-775Z_01a-2c67f3:stalled`
at 2026-09-30T15:00:41Z. Alert text: agent-supervision: omp-2026-09-30T14-42-48-775Z_01a-2c67f3 stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-07T14:54:38Z ×2

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
