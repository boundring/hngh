<!-- plan: status=accepted risk=normal accepted=2026-09-29T14:05:41Z routed-from=supervision:omp-__advisor-81ac0b:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-06T14:00:53Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-09-29 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-__advisor-81ac0b:stalled`
at 2026-09-29T14:00:53Z. Alert text: agent-supervision: omp-__advisor-81ac0b stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-06T13:36:04Z ×2

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
