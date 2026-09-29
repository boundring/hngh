<!-- plan: status=accepted risk=normal accepted=2026-09-29T14:05:41Z routed-from=supervision:slicec2-stall:stalled -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-06T12:01:06Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-09-29 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision:slicec2-stall:stalled`
at 2026-09-29T12:01:06Z. Alert text: agent-supervision: slicec2-stall died after 2 missed ticks (stalled) cause=unclassified [close-run: rc=0 accepted

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
