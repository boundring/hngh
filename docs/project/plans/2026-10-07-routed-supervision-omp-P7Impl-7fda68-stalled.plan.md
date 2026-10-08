<!-- plan: status=accepted risk=normal accepted=2026-10-08T05:06:56Z routed-from=supervision:omp-P7Impl-7fda68:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-14T17:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-07 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-P7Impl-7fda68:stalled`
at 2026-10-07T17:00:42Z. Alert text: agent-supervision: omp-P7Impl-7fda68 stalled (missed tick 1) — steer: hard error result, no corrective step: 373:pub enum EventKind { 374-    LevelGenerated, 375-    EntitySpawn, 376-    EntityDespawn, 377-    EntityMoved, 378-    TileChanged, 379-    FurnitureChanged, cause=repeat-loop expires=2026-10-14T16:29:51Z

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
