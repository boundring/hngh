<!-- plan: status=proposed risk=normal accepted=- routed-from=loop-signal -->
# 2026-09-07 — routed candidate

Routed by scripts/router-tick.py from alert identity `loop-signal`
at 2026-09-07T00:00:37Z. Alert text: [oversight] loop-signal:  /tmp/hngh-fasttest hngh (3 markers in 5m)

## Steps

- [ ] Stop the stalled session, write a handoff brief (last state + next action), start the replacement
      Verification: old session id gone from supervision state; handoff brief file exists; replacement session shows fresh tool activity
