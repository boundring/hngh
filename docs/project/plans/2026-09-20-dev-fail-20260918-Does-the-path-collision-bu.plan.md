<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-20 - dev-fail-20260918-Does-the-path-collision-bu (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line for robustifying the hngh-automation pipeline by introducing a standardized pre-flight validation layer that ensures job definitions and cadence scripts are syntactically sound before execution.

## Steps

- [ ] Create `lib/validate.sh` containing a function to check if a given file path exists and is non-empty.
  Verification: bash -n lib/validate.sh

- [ ] Add a test case in `tests/test_validate.sh` that sources `lib/validate.sh` and asserts the function returns zero for an existing file.
  Verification: make test

- [ ] Create `cadence/preflight.sh` that iterates through job definitions in `jobs/` and invokes the validation logic from `lib/validate.sh`.
  Verification: bash -n cadence/preflight.sh

- [ ] Update `scripts/run_pipeline.sh` to source `cadence/preflight.sh` before executing any job commands.
  Verification: bash -n scripts/run_pipeline.sh

- [ ] Add a dummy job definition file at `jobs/example_job.json` to serve as a fixture for the preflight validation tests.
  Verification: grep -q "example_job" jobs/example_job.json
