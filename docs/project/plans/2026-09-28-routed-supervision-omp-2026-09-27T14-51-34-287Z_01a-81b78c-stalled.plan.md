<!-- plan: status=proposed risk=normal accepted=- routed-from=supervision:omp-2026-09-27T14-51-34-287Z_01a-81b78c:stalled -->
<!-- attempt: 2 -->
<!-- expires: 2026-10-05T16:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-09-28 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-2026-09-27T14-51-34-287Z_01a-81b78c:stalled`
at 2026-09-28T16:00:41Z. Alert text: agent-supervision: omp-2026-09-27T14-51-34-287Z_01a-81b78c stalled (missed tick 1) — steer: no transcript evidence this tick expires=2026-10-04T15:51:45Z ×70

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
