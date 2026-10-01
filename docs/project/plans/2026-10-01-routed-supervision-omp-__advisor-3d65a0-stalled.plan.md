<!-- plan: status=accepted risk=normal accepted=2026-10-01T02:05:49Z routed-from=supervision:omp-__advisor-3d65a0:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-08T02:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-01 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-__advisor-3d65a0:stalled`
at 2026-10-01T02:00:41Z. Alert text: agent-supervision: omp-__advisor-3d65a0 stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-08T01:53:07Z ×2

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
