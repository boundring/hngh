<!-- plan: status=proposed risk=normal accepted=- routed-from=dash-selfreview:feed-fresh:time-ledger.json -->
# 2026-09-22 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:feed-fresh:time-ledger.json`
at 2026-09-22T01:14:10Z. Alert text: [dash-selfreview] feed-fresh:time-ledger.json: unacceptable-now — stale 100145s > 3x tier 300s — producer for time-ledger.json is not firing or is failing

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
