<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-18 - dev-fail-20260917-Does-the-in-toto-v1-schema (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line for standardizing CI validation by introducing a lightweight shell-based test harness and enforcing strict bash syntax checks across all automation scripts to ensure reliable pipeline execution without altering core kernel or security configurations.

## Steps

- [ ] Create `tests/test_harness.sh` with basic assertion functions and exit codes
  Verification: bash -n tests/test_harness.sh

- [ ] Add `scripts/lint_scripts.sh` that iterates through `jobs/` and `cadence/` to run `bash -n` on all `.sh` files
  Verification: bash scripts/lint_scripts.sh

- [ ] Update `Makefile` to add a `test` target that executes `tests/test_harness.sh` and `scripts/lint_scripts.sh`
  Verification: make test

- [ ] Create `lib/utils.sh` containing shared helper functions for logging and error handling
  Verification: bash -n lib/utils.sh

- [ ] Add `dashboard/status_report.sh` to generate a plain text summary of recent job statuses
  Verification: bash dashboard/status_report.sh
