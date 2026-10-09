<!-- plan: status=accepted risk=normal accepted=2026-10-09T11:07:04Z routed-from=review-finding:2026-10-09:escalation-hngh-4pe-dispatch-capped-row -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-16T11:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-09 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-09:escalation-hngh-4pe-dispatch-capped-row`
at 2026-10-09T11:00:42Z. Alert text: escalation hngh-4pe dispatch-capped row bumped to ×124 and slow-unit:dropin:41-newspaper-edition.sh re-occurred 13th time without landing; both rows churn indefinitely under "expires on silence" SLAs that silence never reaches — parked identities are piling, not converging fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
