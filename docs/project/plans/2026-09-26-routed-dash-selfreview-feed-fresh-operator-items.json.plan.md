<!-- plan: status=proposed risk=normal accepted=- routed-from=dash-selfreview:feed-fresh:operator-items.json -->
<!-- attempt: 2 -->
<!-- expires: 2026-10-03T13:00:13Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-09-26 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:feed-fresh:operator-items.json`
at 2026-09-26T13:00:13Z. Alert text: [dash-selfreview] feed-fresh:operator-items.json: unacceptable-now — stale 972s > 3x tier 60s — producer for operator-items.json is not firing or is failing

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-26T14:00:13Z re-occurred (dedup window expired)
