<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-10 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
Implements the research line on *cadence-job reliability and verification harness* to ensure scheduled automation tasks execute deterministically and report status without external dependencies.

## Steps

- [ ] Create a shell script to validate job definition syntax
  Verification: bash -n scripts/validate-job.sh

- [ ] Create a sample job definition for testing
  Verification: grep -q 'job_id' tests/fixtures/sample-job.conf

- [ ] Create a unit test for the job validator
  Verification: bash -n tests/test-validate-job.sh

- [ ] Integrate the validator into the cadence runner
  Verification: grep -q 'validate-job' cadence/run-job.sh

- [ ] Add a library function for job status reporting
  Verification: bash -n lib/job-status.sh

- [ ] Run the full test suite to confirm integration
  Verification: make test
