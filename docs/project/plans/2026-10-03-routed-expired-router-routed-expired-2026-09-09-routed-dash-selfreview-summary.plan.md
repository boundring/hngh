<!-- plan: status=accepted risk=normal accepted=2026-10-03T19:05:54Z routed-from=expired:router:routed-expired:2026-09-09-routed-dash-selfreview-summary -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-10T19:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-03 — routed candidate

Routed by scripts/router-tick.py from alert identity `expired:router:routed-expired:2026-09-09-routed-dash-selfreview-summary`
at 2026-10-03T19:00:41Z. Alert text: identity expired: router:routed-expired:2026-09-09-routed-dash-selfreview-summary cannot close within its window (expires=2026-10-03T13:00:12Z); auto-parked after one operator escalation -- close the condition or re-arm by clearing its identity state

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
