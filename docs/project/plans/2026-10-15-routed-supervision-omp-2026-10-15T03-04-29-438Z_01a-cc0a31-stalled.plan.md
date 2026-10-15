<!-- plan: status=accepted risk=normal accepted=2026-10-15T06:06:42Z routed-from=supervision:omp-2026-10-15T03-04-29-438Z_01a-cc0a31:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-22T04:00:12Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-15 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-2026-10-15T03-04-29-438Z_01a-cc0a31:stalled`
at 2026-10-15T04:00:12Z. Alert text: agent-supervision: omp-2026-10-15T03-04-29-438Z_01a-cc0a31 stalled (missed tick 1) — steer: hard error result, no corrective step: Path 'm00065–m00073' not found cause=repeat-loop expires=2026-10-22T03:28:15Z ×3

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
