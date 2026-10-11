<!-- plan: status=accepted risk=normal accepted=2026-10-11T19:06:34Z routed-from=supervision:omp-LoginMenuSlice-12818c:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-18T19:00:12Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-11 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-LoginMenuSlice-12818c:stalled`
at 2026-10-11T19:00:12Z. Alert text: agent-supervision: omp-LoginMenuSlice-12818c stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-18T18:12:29Z ×8

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
