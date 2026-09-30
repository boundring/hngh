<!-- plan: status=accepted risk=normal accepted=2026-09-30T12:06:33Z routed-from=dash-selfreview:feed-fresh:sessions.json -->
<!-- attempt: 3 -->
<!-- expires: 2026-10-07T09:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-09-30 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:feed-fresh:sessions.json`
at 2026-09-30T09:00:42Z. Alert text: [dash-selfreview] feed-fresh:sessions.json: unacceptable-now — stale 960s > 3x tier 60s — producer for sessions.json is not firing or is failing ×6

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
