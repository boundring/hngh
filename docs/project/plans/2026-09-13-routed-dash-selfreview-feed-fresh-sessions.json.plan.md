<!-- plan: status=proposed risk=normal accepted=- routed-from=dash-selfreview:feed-fresh:sessions.json -->
# 2026-09-13 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:feed-fresh:sessions.json`
at 2026-09-13T15:25:39Z. Alert text: [dash-selfreview] feed-fresh:sessions.json: unacceptable-now — stale 8551s > 3x tier 60s — producer for sessions.json is not firing or is failing

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
