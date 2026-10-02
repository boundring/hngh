<!-- plan: status=accepted risk=normal accepted=2026-10-02T14:05:48Z routed-from=supervision:omp-__advisor-f2dfd1:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-09T11:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-__advisor-f2dfd1:stalled`
at 2026-10-02T11:00:41Z. Alert text: agent-supervision: omp-__advisor-f2dfd1 stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-09T10:21:54Z ×6

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
