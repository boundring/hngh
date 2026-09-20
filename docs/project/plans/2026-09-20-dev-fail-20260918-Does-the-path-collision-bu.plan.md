<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-20 - dev-fail-20260918-Does-the-path-collision-bu (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line for standardizing job execution wrappers by introducing a reusable bash helper library and updating existing automation jobs to utilize it, ensuring consistent error handling and logging across the hngh-automation repository.

## Steps

- [ ] Create `lib/common.sh` containing shared utility functions for logging and exit code management
  Verification: bash -n lib/common.sh
- [ ] Update `jobs/build.sh` to source `lib/common.sh` and replace manual error handling with the new helper functions
  Verification: make test
- [ ] Update `jobs/test.sh` to source `lib/common.sh` and ensure all failure paths invoke the standard exit handler
  Verification: make test
- [ ] Add a smoke test script `tests/lib_smoke.sh` that sources `lib/common.sh` and asserts the presence of required functions
  Verification: bash tests/lib_smoke.sh
