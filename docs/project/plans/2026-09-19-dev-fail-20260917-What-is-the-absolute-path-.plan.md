<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-19 - dev-fail-20260917-What-is-the-absolute-path- (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line for standardizing job execution by introducing a shared validation library and updating the CI entrypoint to enforce script syntax checks before execution.

## Steps

- [ ] Create `lib/validate.sh` containing a `check_syntax` function that runs `bash -n` on a provided file path and exits non-zero on failure.
  Verification: `bash -n lib/validate.sh`

- [ ] Add a test script at `tests/test_validate.sh` that sources `lib/validate.sh`, creates a temporary syntactically invalid bash file, asserts `check_syntax` returns non-zero, then creates a valid file and asserts success.
  Verification: `bash tests/test_validate.sh`

- [ ] Update `jobs/run_job.sh` to source `lib/validate.sh` at the top and call `check_syntax` on the target script path before executing it.
  Verification: `bash -n jobs/run_job.sh`

- [ ] Modify `scripts/ci_entrypoint.sh` to iterate through scripts in `jobs/`, invoking `bash -n` on each file and failing the build if any syntax error is detected.
  Verification: `bash -n scripts/ci_entrypoint.sh`

- [ ] Execute the repository test suite to ensure the new library integration does not break existing job execution flows or CI logic.
  Verification: `make test`
