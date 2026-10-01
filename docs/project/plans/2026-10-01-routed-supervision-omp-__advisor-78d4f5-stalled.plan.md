<!-- plan: status=accepted risk=normal accepted=2026-10-01T02:05:49Z routed-from=supervision:omp-__advisor-78d4f5:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-08T02:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-01 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-__advisor-78d4f5:stalled`
at 2026-10-01T02:00:41Z. Alert text: agent-supervision: omp-__advisor-78d4f5 stalled (missed tick 1) — steer: identical tool call x3: read cause=repeat-loop expires=2026-10-08T01:17:36Z ×5

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
