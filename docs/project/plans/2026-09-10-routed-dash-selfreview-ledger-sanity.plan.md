<!-- plan: status=accepted risk=normal accepted=2026-09-10T19:01:32Z routed-from=dash-selfreview:ledger-sanity -->
# 2026-09-10 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:ledger-sanity`
at 2026-09-10T19:00:18Z. Alert text: [dash-selfreview] ledger-sanity: unacceptable-now — drift 1811 rows (259 ledger vs 2070 bodies) > 50 — queue panel would show rows whose bodies are gone; reconcile/prune

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
