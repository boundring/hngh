<!-- plan: status=accepted risk=normal accepted=2026-10-12T02:35:25Z routed-from=supervision:omp-LoginMenuSlice-940b41:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-18T23:00:12Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-11 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-LoginMenuSlice-940b41:stalled`
at 2026-10-11T23:00:12Z. Alert text: agent-supervision: omp-LoginMenuSlice-940b41 stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-18T22:32:26Z ×5

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
