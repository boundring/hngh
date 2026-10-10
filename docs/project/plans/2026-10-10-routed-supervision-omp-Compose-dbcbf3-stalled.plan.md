<!-- plan: status=proposed risk=normal accepted=- routed-from=supervision:omp-Compose-dbcbf3:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-17T04:00:43Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-10 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-Compose-dbcbf3:stalled`
at 2026-10-10T04:00:43Z. Alert text: agent-supervision: omp-Compose-dbcbf3 stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-17T03:19:41Z ×3

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
