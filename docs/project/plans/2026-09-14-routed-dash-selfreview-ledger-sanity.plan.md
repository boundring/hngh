<!-- plan: status=proposed risk=normal accepted=- routed-from=dash-selfreview:ledger-sanity -->
# 2026-09-14 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:ledger-sanity`
at 2026-09-14T00:00:40Z. Alert text: [dash-selfreview] ledger-sanity: unacceptable-now — drift 2407 rows (395 ledger vs 2802 bodies) > 50 — queue panel would show rows whose bodies are gone; reconcile/prune

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
