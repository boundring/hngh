<!-- plan: status=proposed risk=normal accepted=- routed-from=dash-selfreview:ledger-sanity -->
# 2026-09-11 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:ledger-sanity`
at 2026-09-11T19:00:49Z. Alert text: [dash-selfreview] ledger-sanity: unacceptable-now — drift 1761 rows (485 ledger vs 2246 bodies) > 50 — queue panel would show rows whose bodies are gone; reconcile/prune

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-11T20:00:49Z re-occurred (dedup window expired)
