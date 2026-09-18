<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-18 - dev-fail-20260917-Is-there-a-defined-audit-l (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line for standardizing job execution by introducing a unified wrapper script that enforces consistent environment variables and logging formats across all automation tasks.

## Steps

- [ ] Create `scripts/run_job.sh` to encapsulate common pre-flight checks and log redirection logic.
  Verification: bash -n scripts/run_job.sh
- [ ] Add `lib/job_env.sh` to define standard environment variables for job execution context.
  Verification: bash -n lib/job_env.sh
- [ ] Update `jobs/nightly_build.sh` to source the new library and invoke the wrapper script.
  Verification: make test
- [ ] Implement `tests/test_job_wrapper.sh` to verify the wrapper handles missing environment variables correctly.
  Verification: bash tests/test_job_wrapper.sh
