<!-- plan: status=proposed risk=normal accepted=- routed-from=dash-selfreview:ledger-sanity -->
# 2026-09-12 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:ledger-sanity`
at 2026-09-12T23:00:49Z. Alert text: [dash-selfreview] ledger-sanity: unacceptable-now — drift 2442 rows (80 ledger vs 2522 bodies) > 50 — queue panel would show rows whose bodies are gone; reconcile/prune

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-13T00:00:13Z re-occurred (dedup window expired)
