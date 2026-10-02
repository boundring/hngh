<!-- plan: status=proposed risk=normal accepted=- routed-from=supervision:omp-2026-10-02T19-03-00-885Z_01a-3fd2b8:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-09T20:00:50Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-2026-10-02T19-03-00-885Z_01a-3fd2b8:stalled`
at 2026-10-02T20:00:50Z. Alert text: agent-supervision: omp-2026-10-02T19-03-00-885Z_01a-3fd2b8 stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-09T19:33:14Z ×2

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
