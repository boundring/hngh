<!-- plan: status=parked risk=normal accepted=- routed-from=dash-selfreview:feed-fresh:operator-items.json  cause=obsolete disposed=2026-09-13T18:00:39Z reason=identity re-occurred 3 times without landing; operator escalation stands  cause=obsolete disposed=2026-09-24T23:00:38Z reason=identity re-occurred 4 times without landing; operator escalation stands -->
# 2026-09-13 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:feed-fresh:operator-items.json`
at 2026-09-13T15:25:39Z. Alert text: [dash-selfreview] feed-fresh:operator-items.json: unacceptable-now — stale 8551s > 3x tier 60s — producer for operator-items.json is not firing or is failing

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-13T16:00:13Z re-occurred (dedup window expired)
- 2026-09-13T17:00:39Z re-occurred (dedup window expired)
- 2026-09-13T18:00:39Z re-occurred (dedup window expired)
- 2026-09-24T23:00:38Z re-occurred (dedup window expired)
