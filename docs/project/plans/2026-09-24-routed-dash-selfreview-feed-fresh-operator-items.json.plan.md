<!-- plan: status=proposed risk=normal accepted=- routed-from=dash-selfreview:feed-fresh:operator-items.json -->
# 2026-09-24 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:feed-fresh:operator-items.json`
at 2026-09-24T23:00:38Z. Alert text: [dash-selfreview] feed-fresh:operator-items.json: unacceptable-now — stale 2704s > 3x tier 60s — producer for operator-items.json is not firing or is failing

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
