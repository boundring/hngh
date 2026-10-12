<!-- plan: status=proposed risk=normal accepted=- routed-from=supervision:omp-2026-10-12T01-33-55-557Z_01a-4a24f2:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-19T02:00:12Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-12 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-2026-10-12T01-33-55-557Z_01a-4a24f2:stalled`
at 2026-10-12T02:00:12Z. Alert text: agent-supervision: omp-2026-10-12T01-33-55-557Z_01a-4a24f2 stalled (missed tick 1) — steer: hard error result, no corrective step: Tool todo not found cause=repeat-loop expires=2026-10-19T01:43:27Z

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
