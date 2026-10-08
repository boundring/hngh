<!-- plan: status=accepted risk=normal accepted=2026-10-08T05:06:56Z routed-from=supervision:omp-CisternImpl-bab752:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-14T06:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-07 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-CisternImpl-bab752:stalled`
at 2026-10-07T06:00:42Z. Alert text: agent-supervision: omp-CisternImpl-bab752 stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-14T05:26:01Z

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
