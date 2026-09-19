<!-- plan: status=accepted risk=normal accepted=2026-09-19T19:04:00Z routed-from=dash-selfreview:feed-fresh:readout.json -->
# 2026-09-19 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:feed-fresh:readout.json`
at 2026-09-19T14:16:33Z. Alert text: [dash-selfreview] feed-fresh:readout.json: unacceptable-now — stale 56788s > 3x tier 1800s — producer for readout.json is not firing or is failing

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
