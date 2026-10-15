<!-- plan: status=accepted risk=normal accepted=2026-10-15T20:07:23Z routed-from=supervision:omp-2026-10-15T18-38-11-745Z_01a-2e16bb:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-22T20:00:12Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-15 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-2026-10-15T18-38-11-745Z_01a-2e16bb:stalled`
at 2026-10-15T20:00:12Z. Alert text: agent-supervision: omp-2026-10-15T18-38-11-745Z_01a-2e16bb stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-22T19:30:57Z

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
