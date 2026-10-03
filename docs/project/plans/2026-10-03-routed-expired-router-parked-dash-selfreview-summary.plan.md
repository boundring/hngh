<!-- plan: status=accepted risk=normal accepted=2026-10-03T18:06:04Z routed-from=expired:router:parked:dash-selfreview:summary -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-10T18:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-03 — routed candidate

Routed by scripts/router-tick.py from alert identity `expired:router:parked:dash-selfreview:summary`
at 2026-10-03T18:00:41Z. Alert text: identity expired: router:parked:dash-selfreview:summary cannot close within its window (expires=2026-10-03T13:00:13Z); auto-parked after one operator escalation -- close the condition or re-arm by clearing its identity state

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
