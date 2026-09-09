<!-- plan: status=accepted risk=normal accepted=2026-09-09T01:01:49Z routed-from=overnight:bridge-refused:2026-09-03-routed-agent-stall-omp-hngh-action-reduction-312cd0 -->
# 2026-09-09 — routed candidate

Routed by scripts/router-tick.py from alert identity `overnight:bridge-refused:2026-09-03-routed-agent-stall-omp-hngh-action-reduction-312cd0`
at 2026-09-09T01:00:16Z. Alert text: overnight beat 2026-09-03-routed-agent-stall-omp-hngh-action-reduction-312cd0 could not open a bridge run: conflict labels=record-conflict

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
