<!-- plan: status=proposed risk=normal accepted=- routed-from=supervision:omp-2026-10-14T02-30-06-239Z_01a-0d69f5:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-21T03:00:14Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-14 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-2026-10-14T02-30-06-239Z_01a-0d69f5:stalled`
at 2026-10-14T03:00:14Z. Alert text: agent-supervision: omp-2026-10-14T02-30-06-239Z_01a-0d69f5 stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-21T02:55:57Z

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
