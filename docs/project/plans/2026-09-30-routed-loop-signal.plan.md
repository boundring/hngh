<!-- plan: status=proposed risk=normal accepted=- routed-from=loop-signal -->
<!-- attempt: 2 -->
<!-- expires: 2026-10-07T03:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-09-30 — routed candidate

Routed by scripts/router-tick.py from alert identity `loop-signal`
at 2026-09-30T03:00:41Z. Alert text: [oversight] loop-signal:  ~tmp/hngh-fasttest bili (4 markers in 5m)

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
