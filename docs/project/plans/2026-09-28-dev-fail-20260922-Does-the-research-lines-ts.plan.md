<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-28 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence script that validates all job definitions parse correctly before scheduling
  Verification: bash scripts/cadence/validate-jobs.sh

- [ ] Create a test helper that asserts job output conforms to expected schema
  Verification: python3 tests/test_job_schema.py

- [ ] Update cadence runner to gate execution on validation script passing
  Verification: bash -n cadence/runner.sh && make test

- [ ] Add a dashboard digest that reports job success rates per cadence window
  Verification: bash scripts/digest/report-cadence.sh

- [ ] Extend lib utilities with a job-dependency resolver for parallel execution
  Verification: python3 lib/job_resolver.py && make test

- [ ] Add a test suite covering cadence ordering and parallel job isolation
  Verification: make test
