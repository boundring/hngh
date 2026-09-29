<!-- plan: status=expired risk=normal accepted=- routed-from=dash-selfreview:feed-fresh:sessions.json -->
<!-- attempt: 2 -->
<!-- expires: 2026-10-05T08:00:43Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-09-28 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:feed-fresh:sessions.json`
at 2026-09-28T08:00:43Z. Alert text: [dash-selfreview] feed-fresh:sessions.json: unacceptable-now — stale 1145s > 3x tier 60s — producer for sessions.json is not firing or is failing

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-29T08:00:53Z re-occurred (dedup window expired)
