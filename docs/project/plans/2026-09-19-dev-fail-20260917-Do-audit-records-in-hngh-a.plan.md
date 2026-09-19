<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-19 - dev-fail-20260917-Do-audit-records-in-hngh-a (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line for standardizing CI gate verification by introducing a lightweight shell-based validation harness that ensures all job definitions and automation scripts pass syntax checks before merging.

## Steps

- [ ] Create `scripts/validate_jobs.sh` to iterate through `jobs/*.yaml` files and verify required fields exist using grep
  Verification: bash -n scripts/validate_jobs.sh
- [ ] Add a test fixture in `tests/fixtures/sample_job.yaml` with valid structure for the validator to consume
  Verification: git ls-files tests/fixtures/sample_job.yaml | grep -q "sample_job.yaml"
- [ ] Implement `lib/job_lint.py` using only stdlib to parse YAML-like structures and return exit codes for validation logic
  Verification: python3 lib/job_lint.py --help
- [ ] Update `cadence/ci_gate.sh` to invoke the new validator script before proceeding with deployment steps
  Verification: bash -n cadence/ci_gate.sh
- [ ] Add a regression test in `tests/test_validation.sh` that asserts the validator fails on malformed input
  Verification: bash tests/test_validation.sh
