<!-- plan: status=expired risk=normal accepted=- routed-from=dash-selfreview:feed-fresh:readout.json -->
# 2026-09-18 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:feed-fresh:readout.json`
at 2026-09-18T12:31:29Z. Alert text: [dash-selfreview] feed-fresh:readout.json: unacceptable-now — stale 75685s > 3x tier 1800s — producer for readout.json is not firing or is failing

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-19T14:16:33Z re-occurred (dedup window expired)
- 2026-09-22T01:14:09Z re-occurred (dedup window expired)
