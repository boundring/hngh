<!-- plan: status=accepted risk=normal accepted=2026-10-02T14:05:48Z routed-from=dash-selfreview:feed-fresh:sessions.json -->
<!-- attempt: 3 -->
<!-- expires: 2026-10-09T13:00:45Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:feed-fresh:sessions.json`
at 2026-10-02T13:00:45Z. Alert text: [dash-selfreview] feed-fresh:sessions.json: unacceptable-now — stale 403s > 3x tier 60s — producer for sessions.json is not firing or is failing

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
