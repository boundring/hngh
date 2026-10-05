<!-- plan: status=accepted risk=normal accepted=2026-10-05T01:05:49Z routed-from=supervision:omp-2026-10-05T00-27-42-572Z_01a-9758fd:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-12T01:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-05 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-2026-10-05T00-27-42-572Z_01a-9758fd:stalled`
at 2026-10-05T01:00:42Z. Alert text: agent-supervision: omp-2026-10-05T00-27-42-572Z_01a-9758fd stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-12T00:55:12Z

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
