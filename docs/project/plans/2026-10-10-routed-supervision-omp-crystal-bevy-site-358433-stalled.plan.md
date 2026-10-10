<!-- plan: status=accepted risk=normal accepted=2026-10-10T15:07:18Z routed-from=supervision:omp-crystal-bevy-site-358433:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-17T15:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-10 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-crystal-bevy-site-358433:stalled`
at 2026-10-10T15:00:42Z. Alert text: agent-supervision: omp-crystal-bevy-site-358433 stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-17T14:41:38Z

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
