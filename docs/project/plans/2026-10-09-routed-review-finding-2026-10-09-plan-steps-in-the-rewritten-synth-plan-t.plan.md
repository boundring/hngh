<!-- plan: status=accepted risk=normal accepted=2026-10-09T11:07:04Z routed-from=review-finding:2026-10-09:plan-steps-in-the-rewritten-synth-plan-t -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-16T11:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-09 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-09:plan-steps-in-the-rewritten-synth-plan-t`
at 2026-10-09T11:00:42Z. Alert text: plan steps in the rewritten synth plan target `jobs/runner.sh`, `dashboard/ingest.sh`, `lib/cadence_status.sh` with no repo qualifier — scope ambiguity across repo boundaries (hngh ledger committing a plan that mutates automation-side surfaces) fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
