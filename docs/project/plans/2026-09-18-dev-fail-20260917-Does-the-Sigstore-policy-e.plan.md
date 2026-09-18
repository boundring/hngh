<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-18 - dev-fail-20260917-Does-the-Sigstore-policy-e (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line for standardizing job execution wrappers by introducing a reusable bash helper library to enforce consistent environment variable propagation and logging conventions across all automation jobs.

## Steps

- [ ] Create `lib/job_env.sh` containing functions to validate required environment variables and format log prefixes.
  Verification: bash -n lib/job_env.sh
- [ ] Add `tests/test_job_env.sh` with a test suite that sources the library and asserts error codes for missing variables.
  Verification: make test
- [ ] Update `jobs/nightly_build.sh` to source `lib/job_env.sh` and replace manual environment checks with the new helper functions.
  Verification: bash -n jobs/nightly_build.sh
- [ ] Add a grep check in `tests/test_job_env.sh` to verify that `jobs/nightly_build.sh` contains the source statement for the library.
  Verification: make test
