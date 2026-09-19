<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-19 - dev-fail-20260917-What-is-the-absolute-path- (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line for **standardizing job execution and verification** by consolidating ad-hoc shell logic into reusable, testable components within `hngh-automation`.

## Steps

- [ ] Create a new bash script at `scripts/run_job.sh` that accepts a job ID argument and executes the corresponding job definition.
  Verification: `bash -n scripts/run_job.sh`
- [ ] Add a unit test file at `tests/test_run_job.sh` that sources the library functions and asserts the exit code of a mock job execution.
  Verification: `make test`
- [ ] Update the `lib/helpers.sh` file to include a new function `log_status` that appends timestamped status messages to a standard log path.
  Verification: `bash -n lib/helpers.sh`
- [ ] Create a dashboard configuration snippet at `dashboard/config.yaml` defining the default display parameters for job history.
  Verification: `grep -q "job_history" dashboard/config.yaml`
