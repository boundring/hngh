<!-- plan: status=accepted risk=normal accepted=2026-10-04T18:05:42Z routed-from=expired:router:parked:dash-selfreview:feed-fresh:time-ledger.json -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-11T18:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-04 — routed candidate

Routed by scripts/router-tick.py from alert identity `expired:router:parked:dash-selfreview:feed-fresh:time-ledger.json`
at 2026-10-04T18:00:42Z. Alert text: identity expired: router:parked:dash-selfreview:feed-fresh:time-ledger.json cannot close within its window (expires=2026-10-03T17:00:14Z); auto-parked after one operator escalation -- close the condition or re-arm by clearing its identity state

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
