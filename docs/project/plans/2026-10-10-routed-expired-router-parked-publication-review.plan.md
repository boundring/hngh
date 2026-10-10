<!-- plan: status=accepted risk=normal accepted=2026-10-10T11:07:06Z routed-from=expired:router:parked:publication-review -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-17T11:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-10 — routed candidate

Routed by scripts/router-tick.py from alert identity `expired:router:parked:publication-review`
at 2026-10-10T11:00:42Z. Alert text: identity expired: router:parked:publication-review cannot close within its window (expires=2026-10-08T15:00:41Z); auto-parked after one operator escalation -- close the condition or re-arm by clearing its identity state

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
