<!-- plan: status=parked risk=normal accepted=2026-09-10T19:01:32Z routed-from=dash-selfreview:ledger-sanity  cause=obsolete disposed=2026-09-10T22:00:33Z reason=identity re-occurred 3 times without landing; operator escalation stands -->
# 2026-09-10 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:ledger-sanity`
at 2026-09-10T19:00:18Z. Alert text: [dash-selfreview] ledger-sanity: unacceptable-now — drift 1811 rows (259 ledger vs 2070 bodies) > 50 — queue panel would show rows whose bodies are gone; reconcile/prune

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-10T20:00:18Z re-occurred (dedup window expired)
- 2026-09-10T21:00:12Z re-occurred (dedup window expired)
- 2026-09-10T22:00:33Z re-occurred (dedup window expired)
