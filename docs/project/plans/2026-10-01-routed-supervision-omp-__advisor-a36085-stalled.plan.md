<!-- plan: status=proposed risk=normal accepted=- routed-from=supervision:omp-__advisor-a36085:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-08T11:30:55Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-01 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-__advisor-a36085:stalled`
at 2026-10-01T11:30:55Z. Alert text: agent-supervision: omp-__advisor-a36085 stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-08T09:24:02Z ×11

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
