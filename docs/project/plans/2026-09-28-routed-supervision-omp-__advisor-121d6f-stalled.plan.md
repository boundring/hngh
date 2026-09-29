<!-- plan: status=accepted risk=normal accepted=2026-09-29T14:05:41Z routed-from=supervision:omp-__advisor-121d6f:stalled -->
<!-- attempt: 2 -->
<!-- expires: 2026-10-05T16:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-09-28 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-__advisor-121d6f:stalled`
at 2026-09-28T16:00:41Z. Alert text: agent-supervision: omp-__advisor-121d6f stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-04T15:51:45Z ×76

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
