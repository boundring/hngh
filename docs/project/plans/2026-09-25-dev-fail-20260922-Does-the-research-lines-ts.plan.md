<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-25 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job template for task pipeline tracking under jobs/
  Verification: bash -n jobs/task-pipeline-template.sh

- [ ] Create a verification script that confirms job template syntax
  Verification: bash scripts/verify-job-template.sh

- [ ] Add a test case for the new job template
  Verification: make test

- [ ] Update cadence tracking to include new job type
  Verification: bash -n cadence/cadence-tracker.sh

- [ ] Add dashboard snippet for new job type visualization
  Verification: bash -n dashboard/dashboard-snippet.sh

- [ ] Run full test suite to confirm no regressions
  Verification: make test
