<!-- plan: status=parked risk=normal accepted=2026-09-09T20:01:16Z routed-from=dash-selfreview:ledger-sanity  cause=superseded disposed=2026-09-09T21:01:28Z reason="same fix operation and verification as 2026-09-08-routed-dash-selfreview-summary; consolidated per queue-dependency-inventory merge candidate 2" -->
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
