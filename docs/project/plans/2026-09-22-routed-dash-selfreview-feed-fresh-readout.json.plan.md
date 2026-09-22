<!-- plan: status=accepted risk=normal accepted=2026-09-22T13:03:06Z routed-from=dash-selfreview:feed-fresh:readout.json -->
# 2026-09-22 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:feed-fresh:readout.json`
at 2026-09-22T01:14:10Z. Alert text: [dash-selfreview] feed-fresh:readout.json: unacceptable-now — stale 100223s > 3x tier 1800s — producer for readout.json is not firing or is failing

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
