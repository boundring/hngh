<!-- plan: status=accepted risk=normal accepted=2026-10-14T04:35:29Z routed-from=review-finding:2026-10-13:accept-plans-idempotence-broken-reports -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-21T03:00:14Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-14 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-13:accept-plans-idempotence-broken-reports`
at 2026-10-14T03:00:14Z. Alert text: accept-plans idempotence broken — reports.md logs the identical "plan 2026-10-12-dev-env-contract-checkable auto-accepted" line ×3 then ×4 with the same accepted timestamp; dedup is not holding fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
