<!-- plan: status=accepted risk=normal accepted=2026-10-14T06:06:33Z routed-from=supervision:omp-2026-10-14T02-40-07-361Z_01a-d42a9d:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-21T06:00:12Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-14 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-2026-10-14T02-40-07-361Z_01a-d42a9d:stalled`
at 2026-10-14T06:00:12Z. Alert text: agent-supervision: omp-2026-10-14T02-40-07-361Z_01a-d42a9d stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-21T03:22:48Z ×25

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
