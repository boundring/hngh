<!-- plan: status=accepted risk=normal accepted=2026-09-25T02:03:34Z routed-from=dash-selfreview:feed-fresh:time-ledger.json -->
# 2026-09-24 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:feed-fresh:time-ledger.json`
at 2026-09-24T23:00:37Z. Alert text: [dash-selfreview] feed-fresh:time-ledger.json: unacceptable-now — stale 2733s > 3x tier 300s — producer for time-ledger.json is not firing or is failing

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-25T00:00:38Z re-occurred (dedup window expired)
