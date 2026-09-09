<!-- plan: status=accepted risk=normal accepted=2026-09-09T20:01:16Z routed-from=dash-selfreview:ledger-sanity -->
# 2026-09-09 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:ledger-sanity`
at 2026-09-09T19:00:18Z. Alert text: [dash-selfreview] ledger-sanity: unacceptable-now — drift 1880 rows (2 ledger vs 1882 bodies) > 50 — queue panel would show rows whose bodies are gone; reconcile/prune

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-09T20:00:18Z re-occurred (dedup window expired)
