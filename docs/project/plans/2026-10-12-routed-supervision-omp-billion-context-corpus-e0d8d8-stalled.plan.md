<!-- plan: status=accepted risk=normal accepted=2026-10-14T00:05:44Z routed-from=supervision:omp-billion-context-corpus-e0d8d8:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-19T14:00:12Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-12 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-billion-context-corpus-e0d8d8:stalled`
at 2026-10-12T14:00:12Z. Alert text: agent-supervision: omp-billion-context-corpus-e0d8d8 stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-19T13:23:02Z ×7

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
