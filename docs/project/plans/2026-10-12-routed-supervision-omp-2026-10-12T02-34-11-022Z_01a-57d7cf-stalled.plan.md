<!-- plan: status=accepted risk=normal accepted=2026-10-12T06:35:30Z routed-from=supervision:omp-2026-10-12T02-34-11-022Z_01a-57d7cf:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-19T04:00:12Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-12 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-2026-10-12T02-34-11-022Z_01a-57d7cf:stalled`
at 2026-10-12T04:00:12Z. Alert text: agent-supervision: omp-2026-10-12T02-34-11-022Z_01a-57d7cf stalled (missed tick 1) — steer: hard error result, no corrective step: Path not found: ~/.local/share/jcode-app, jcode-linux-x86_64.bin cause=repeat-loop expires=2026-10-19T03:19:29Z

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
