<!-- plan: status=parked risk=normal accepted=2026-09-09T20:01:16Z routed-from=dash-selfreview:ledger-sanity  cause=superseded disposed=2026-09-09T21:01:28Z reason="same fix operation and verification as 2026-09-08-routed-dash-selfreview-summary; consolidated per queue-dependency-inventory merge candidate 2"  cause=obsolete disposed=2026-09-27T13:00:41Z reason=identity re-occurred 6 times without landing; operator escalation stands  cause=obsolete disposed=2026-09-28T13:00:51Z reason=identity re-occurred 7 times without landing; operator escalation stands  cause=obsolete disposed=2026-09-29T13:00:52Z reason=identity re-occurred 8 times without landing; operator escalation stands  cause=obsolete disposed=2026-09-30T14:00:41Z reason=identity re-occurred 9 times without landing; operator escalation stands  cause=obsolete disposed=2026-10-01T17:00:41Z reason=identity re-occurred 10 times without landing; operator escalation stands -->
# 2026-09-09 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:ledger-sanity`
at 2026-09-09T19:00:18Z. Alert text: [dash-selfreview] ledger-sanity: unacceptable-now — drift 1880 rows (2 ledger vs 1882 bodies) > 50 — queue panel would show rows whose bodies are gone; reconcile/prune

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-09T20:00:18Z re-occurred (dedup window expired)
- 2026-09-09T21:00:18Z re-occurred (dedup window expired)
- 2026-09-09T22:00:19Z re-occurred (dedup window expired)
- 2026-09-09T23:00:18Z re-occurred (dedup window expired)
- 2026-09-10T00:00:18Z re-occurred (dedup window expired)
- 2026-09-27T13:00:41Z re-occurred (dedup window expired)
- 2026-09-28T13:00:51Z re-occurred (dedup window expired)
- 2026-09-29T13:00:52Z re-occurred (dedup window expired)
- 2026-09-30T14:00:41Z re-occurred (dedup window expired)
- 2026-10-01T17:00:41Z re-occurred (dedup window expired)
