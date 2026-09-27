<!-- plan: status=proposed risk=normal accepted=- routed-from=dash-selfreview:feed-fresh:time-ledger.json -->
<!-- attempt: 2 -->
<!-- expires: 2026-10-04T06:00:44Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-09-27 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:feed-fresh:time-ledger.json`
at 2026-09-27T06:00:44Z. Alert text: [dash-selfreview] feed-fresh:time-ledger.json: unacceptable-now — stale 1310s > 3x tier 300s — producer for time-ledger.json is not firing or is failing

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
