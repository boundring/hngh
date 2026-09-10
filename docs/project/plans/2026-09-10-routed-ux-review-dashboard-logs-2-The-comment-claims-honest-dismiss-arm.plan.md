<!-- plan: status=proposed risk=normal accepted=- routed-from=ux-review:dashboard-logs:2-The-comment-claims-honest-dismiss-arm -->
# 2026-09-10 — routed candidate

Routed by scripts/router-tick.py from alert identity `ux-review:dashboard-logs:2-The-comment-claims-honest-dismiss-arm`
at 2026-09-10T04:00:18Z. Alert text: 2. The comment claims "honest dismiss... arm first", but the code only arms for items in the `live` list (not dismissed), yet `armedId` persists across renders without clearing on tab switch or new data fetch, allowing stale confirm buttons to appear on unrelated items -> violates "concrete nouns" by describing a state that doesn't match the actual DOM lifecycle -> `hngh-automation.js`. fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
