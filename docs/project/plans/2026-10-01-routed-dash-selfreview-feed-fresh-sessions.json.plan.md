<!-- plan: status=accepted risk=normal accepted=2026-10-01T21:05:43Z routed-from=dash-selfreview:feed-fresh:sessions.json -->
<!-- attempt: 3 -->
<!-- expires: 2026-10-08T12:30:03Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-01 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:feed-fresh:sessions.json`
at 2026-10-01T12:30:03Z. Alert text: [dash-selfreview] feed-fresh:sessions.json: unacceptable-now — stale 875s > 3x tier 60s — producer for sessions.json is not firing or is failing

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
