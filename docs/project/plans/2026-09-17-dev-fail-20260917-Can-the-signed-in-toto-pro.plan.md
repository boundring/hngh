<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-17 - dev-fail-20260917-Can-the-signed-in-toto-pro (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line for standardizing job execution wrappers by introducing a reusable shell helper library to enforce consistent environment setup and logging within the `jobs/` directory.

## Steps

- [ ] Create `lib/job_helpers.sh` containing functions for setting up isolated job environments and capturing exit codes.
  Verification: bash -n lib/job_helpers.sh

- [ ] Update `jobs/run_pipeline.sh` to source `lib/job_helpers.sh` and invoke the new environment setup function before execution.
  Verification: make test

- [ ] Add a unit test script `tests/test_job_helpers.sh` that verifies the helper functions correctly capture non-zero exit codes.
  Verification: bash tests/test_job_helpers.sh

- [ ] Modify `cadence/scheduler.sh` to import the logging utility from `lib/job_helpers.sh` for consistent timestamp formatting.
  Verification: bash -n cadence/scheduler.sh
