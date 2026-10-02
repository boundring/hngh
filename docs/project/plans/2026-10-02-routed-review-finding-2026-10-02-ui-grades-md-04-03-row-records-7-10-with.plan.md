<!-- plan: status=accepted risk=normal accepted=2026-10-02T14:05:48Z routed-from=review-finding:2026-10-02:ui-grades-md-04-03-row-records-7-10-with -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-09T13:00:46Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-02:ui-grades-md-04-03-row-records-7-10-with`
at 2026-10-02T13:00:46Z. Alert text: ui-grades.md 04:03 row records `7/10` with `fg/bg contrast 1.1:1` alongside 12.4:1 siblings at the same tick — self-grade contradicts its own metric and should have tripped a gate, not been ledgered fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
