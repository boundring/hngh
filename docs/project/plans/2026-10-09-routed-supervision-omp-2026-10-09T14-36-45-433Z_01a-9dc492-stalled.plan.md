<!-- plan: status=accepted risk=normal accepted=2026-10-09T16:07:08Z routed-from=supervision:omp-2026-10-09T14-36-45-433Z_01a-9dc492:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-16T16:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-09 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-2026-10-09T14-36-45-433Z_01a-9dc492:stalled`
at 2026-10-09T16:00:42Z. Alert text: agent-supervision: omp-2026-10-09T14-36-45-433Z_01a-9dc492 stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-16T15:08:44Z ×4

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
