<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-20 - dev-fail-20260918-Does-the-path-collision-bu (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line for standardizing job execution and log parsing by introducing a robust shell wrapper and Python-based validation script to ensure consistent output handling across the automation suite.

## Steps

- [ ] Create `scripts/run_job.sh` with basic argument parsing and error trapping
  Verification: bash -n scripts/run_job.sh

- [ ] Add `lib/parse_log.py` using stdlib re module to extract status codes from job logs
  Verification: python3 lib/parse_log.py --help

- [ ] Implement `tests/test_parse_log.py` with three test cases covering success, failure, and timeout scenarios
  Verification: make test

- [ ] Update `jobs/standard_job.sh` to invoke the new wrapper script instead of inline logic
  Verification: bash -n jobs/standard_job.sh

- [ ] Add `cadence/cleanup_old_logs.sh` to prune logs older than 7 days using find and rm
  Verification: bash -n cadence/cleanup_old_logs.sh
