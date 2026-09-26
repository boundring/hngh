<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a job-definition validation script that checks syntax before execution
  Verification: bash scripts/validate-job-def.sh

- [ ] Add unit tests for the validation script covering valid and invalid inputs
  Verification: python3 tests/test_validate_job_def.py

- [ ] Integrate validation script into the main automation workflow
  Verification: make test

- [ ] Add a simple status-reporting helper that outputs job completion state
  Verification: bash scripts/report-status.sh

- [ ] Add integration test verifying end-to-end validation and reporting flow
  Verification: make test

- [ ] Update documentation with new validation and reporting usage
  Verification: grep -r "validate-job-def" jobs/ scripts/ cadence/
