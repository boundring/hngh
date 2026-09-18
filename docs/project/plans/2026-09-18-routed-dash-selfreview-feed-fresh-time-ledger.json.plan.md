<!-- plan: status=proposed risk=normal accepted=- routed-from=dash-selfreview:feed-fresh:time-ledger.json -->
# 2026-09-18 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:feed-fresh:time-ledger.json`
at 2026-09-18T12:31:29Z. Alert text: [dash-selfreview] feed-fresh:time-ledger.json: unacceptable-now — stale 75385s > 3x tier 300s — producer for time-ledger.json is not firing or is failing

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
