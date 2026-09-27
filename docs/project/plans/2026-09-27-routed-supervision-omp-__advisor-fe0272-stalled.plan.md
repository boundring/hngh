<!-- plan: status=proposed risk=normal accepted=- routed-from=supervision:omp-__advisor-fe0272:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-04T13:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-09-27 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-__advisor-fe0272:stalled`
at 2026-09-27T13:00:41Z. Alert text: agent-supervision: omp-__advisor-fe0272 stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-04T12:59:58Z

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
