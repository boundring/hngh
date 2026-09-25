<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-25 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Rationale: Implements the hngh-automation research line for cadence-driven job scheduling verification, adding a lightweight script to validate job definitions before execution.

## Steps

- [ ] Add a validation script for job definition syntax
  Verification: bash -n scripts/validate-job-def.sh

- [ ] Create a test for the validation script
  Verification: make test

- [ ] Add a job definition example to jobs/
  Verification: grep -q "example" jobs/example-job.yaml

- [ ] Update cadence configuration to reference new validation
  Verification: grep -q "validate" cadence/cadence.yaml

- [ ] Add integration test for the full validation flow
  Verification: make test
