<!-- plan: status=parked risk=normal accepted=2026-09-06T01:01:30Z routed-from=overnight:plan-accept-gate:automation  cause=obsolete disposed=2026-09-09T15:27:53Z reason="same resolved premise; no automation-gate acceptance block after 2026-09-08T04:01Z in acceptance.log" cause=obsolete disposed=2026-09-23T06:01:03Z reason=identity re-occurred 3 times without landing; operator escalation stands  cause=obsolete disposed=2026-09-26T04:00:13Z reason=identity re-occurred 4 times without landing; operator escalation stands  cause=obsolete disposed=2026-09-27T11:00:41Z reason=identity re-occurred 5 times without landing; operator escalation stands  cause=obsolete disposed=2026-09-28T12:00:49Z reason=identity re-occurred 6 times without landing; operator escalation stands  cause=obsolete disposed=2026-09-29T12:01:06Z reason=identity re-occurred 7 times without landing; operator escalation stands -->
# 2026-09-06 — routed candidate

Routed by scripts/router-tick.py from alert identity `overnight:plan-accept-gate:automation`
at 2026-09-06T01:00:45Z. Alert text: plan acceptance blocked: hngh-automation make test FAILED (rc=2)

## Steps

- [ ] Re-run the named gate, capture the failing check, fix or park
      Verification: both `make test` gates green; failing check captured

## Occurrences

- 2026-09-23T04:00:13Z re-occurred (dedup window expired)
- 2026-09-23T05:01:03Z re-occurred (dedup window expired)
- 2026-09-23T06:01:03Z re-occurred (dedup window expired)
- 2026-09-26T04:00:13Z re-occurred (dedup window expired)
- 2026-09-27T11:00:41Z re-occurred (dedup window expired)
- 2026-09-28T12:00:49Z re-occurred (dedup window expired)
- 2026-09-29T12:01:06Z re-occurred (dedup window expired)
