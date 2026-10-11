<!-- plan: status=accepted risk=normal accepted=2026-10-11T18:35:29Z routed-from=supervision:omp-NgP1WaveImpl-6d6a92:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-18T18:00:14Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-11 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-NgP1WaveImpl-6d6a92:stalled`
at 2026-10-11T18:00:14Z. Alert text: agent-supervision: omp-NgP1WaveImpl-6d6a92 stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-18T17:32:48Z ×5

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
