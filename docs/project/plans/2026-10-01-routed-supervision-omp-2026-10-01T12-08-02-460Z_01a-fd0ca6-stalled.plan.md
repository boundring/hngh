<!-- plan: status=accepted risk=normal accepted=2026-10-01T21:05:43Z routed-from=supervision:omp-2026-10-01T12-08-02-460Z_01a-fd0ca6:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-08T14:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-01 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-2026-10-01T12-08-02-460Z_01a-fd0ca6:stalled`
at 2026-10-01T14:00:41Z. Alert text: agent-supervision: omp-2026-10-01T12-08-02-460Z_01a-fd0ca6 stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-08T12:31:27Z ×8

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
