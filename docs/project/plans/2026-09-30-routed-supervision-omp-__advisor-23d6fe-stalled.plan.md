<!-- plan: status=accepted risk=normal accepted=2026-09-30T20:06:34Z routed-from=supervision:omp-__advisor-23d6fe:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-07T20:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-09-30 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-__advisor-23d6fe:stalled`
at 2026-09-30T20:00:41Z. Alert text: agent-supervision: omp-__advisor-23d6fe died after 2 missed ticks (stalled; advisory — omp transcripts are never killed) cause=missing-knowledge expires=2026-10-05T17:37:41Z ×12

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
