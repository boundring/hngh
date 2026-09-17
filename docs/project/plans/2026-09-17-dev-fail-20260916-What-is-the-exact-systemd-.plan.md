<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-17 - dev-fail-20260916-What-is-the-exact-systemd- (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line for automating CI gate verification by introducing a lightweight shell-based validation layer that ensures job definitions and script syntax remain consistent without modifying core kernel or provider configurations.

## Steps

- [ ] Create `scripts/validate_jobs.sh` to iterate through `jobs/` directory entries and assert each file contains a valid YAML front-matter block with required keys
  Verification: bash -n scripts/validate_jobs.sh

- [ ] Add a test fixture in `tests/fixtures/sample_job.yaml` containing minimal valid job metadata for regression testing of the validator
  Verification: grep -q "name:" tests/fixtures/sample_job.yaml

- [ ] Implement `lib/job_parser.py` using only stdlib to parse YAML front-matter from job files and return a dictionary of fields
  Verification: python3 lib/job_parser.py --help

- [ ] Extend `make test` target in the root Makefile to invoke `scripts/validate_jobs.sh` before running existing unit tests
  Verification: make test

- [ ] Add a negative test case in `tests/test_validator.sh` that expects failure when a job file lacks the required 'owner' field
  Verification: bash tests/test_validator.sh
