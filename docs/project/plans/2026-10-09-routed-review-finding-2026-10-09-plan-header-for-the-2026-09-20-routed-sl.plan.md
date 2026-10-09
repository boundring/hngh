<!-- plan: status=accepted risk=normal accepted=2026-10-09T10:07:01Z routed-from=review-finding:2026-10-09:plan-header-for-the-2026-09-20-routed-sl -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-16T10:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-09 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-09:plan-header-for-the-2026-09-20-routed-sl`
at 2026-10-09T10:00:42Z. Alert text: plan header for the 2026-09-20 routed slow-unit plan accumulates `cause=obsolete disposed=...` entries unboundedly on a single HTML-comment line (now 13 re-occurrences) — will degrade readability/tooling on long-lived parked identities fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
