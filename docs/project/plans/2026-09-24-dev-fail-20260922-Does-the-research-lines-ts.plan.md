<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-24 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job script under jobs/ that implements a basic data validation task
  Verification: bash -n jobs/data-validation.sh

- [ ] Create a corresponding test script under tests/ that exercises the new job
  Verification: bash -n tests/test-data-validation.sh

- [ ] Update the cadence configuration to register the new job for scheduled execution
  Verification: grep -q 'data-validation' cadence/schedule.yaml

- [ ] Add a verification script under scripts/ that confirms the new job integrates with existing make test
  Verification: make test

- [ ] Create a dashboard snippet under dashboard/ that displays job execution status
  Verification: bash -n dashboard/job-status.sh

- [ ] Add a digest rule under digest/ that logs new job completions
  Verification: bash -n digest/job-digest.sh
