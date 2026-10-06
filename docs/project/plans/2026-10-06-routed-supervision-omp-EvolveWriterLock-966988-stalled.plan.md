<!-- plan: status=proposed risk=normal accepted=- routed-from=supervision:omp-EvolveWriterLock-966988:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-13T19:00:58Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-06 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-EvolveWriterLock-966988:stalled`
at 2026-10-06T19:00:58Z. Alert text: agent-supervision: omp-EvolveWriterLock-966988 stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-13T18:54:19Z

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
