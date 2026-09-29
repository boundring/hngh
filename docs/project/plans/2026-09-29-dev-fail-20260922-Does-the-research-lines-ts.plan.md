<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-29 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence script that validates job definitions against a schema before execution
  Verification: bash scripts/cadence/validate-job.sh

- [ ] Create a test fixture that generates a sample job definition for validation testing
  Verification: python3 tests/test_validate_job.py

- [ ] Update the cadence runner to invoke the validation script before job dispatch
  Verification: bash -n cadence/runner.sh

- [ ] Add a dashboard endpoint that lists validated jobs with their last run status
  Verification: python3 dashboard/list_jobs.py

- [ ] Create a digest summary script that aggregates job validation results for reporting
  Verification: bash scripts/digest/summarize.sh
