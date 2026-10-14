<!-- plan: status=accepted risk=normal accepted=2026-10-14T00:05:44Z routed-from=supervision:omp-fish-crash-triage-beb75d:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-19T15:00:12Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-12 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:omp-fish-crash-triage-beb75d:stalled`
at 2026-10-12T15:00:12Z. Alert text: agent-supervision: omp-fish-crash-triage-beb75d stalled (missed tick 1) — steer: hard error result, no corrective step: /usr/bin/systembus-notify === === Oct 12 10:05:47 brickertop cadence-tick.sh[92801]: grep: warning: stray \ before - Oct 12 10:05:47 brickertop cadence-tick.sh[ cause=repeat-loop expires=2026-10-19T14:25:32Z ×6

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
