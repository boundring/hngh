<!-- plan: status=accepted risk=normal accepted=2026-10-10T10:14:13Z routed-from=supervision:omp-2026-10-10T09-08-48-006Z_01a-b435c5:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-17T10:07:47Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-10 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-2026-10-10T09-08-48-006Z_01a-b435c5:stalled`
at 2026-10-10T10:07:47Z. Alert text: agent-supervision: omp-2026-10-10T09-08-48-006Z_01a-b435c5 stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-17T09:49:52Z ×3

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
