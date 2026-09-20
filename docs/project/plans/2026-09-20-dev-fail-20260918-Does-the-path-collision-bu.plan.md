<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-20 - dev-fail-20260918-Does-the-path-collision-bu (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line for standardizing job execution wrappers by introducing a reusable shell library to enforce consistent logging and error handling across the automation suite.

## Steps

- [ ] Create `lib/common.sh` containing helper functions for timestamped logging and exit code propagation.
  Verification: bash -n lib/common.sh
- [ ] Add `tests/test_common.sh` to verify that the logging function outputs the expected format and propagates non-zero exit codes correctly.
  Verification: make test
- [ ] Update `jobs/build.sh` to source `lib/common.sh` and replace manual echo statements with the new logging helper.
  Verification: bash -n jobs/build.sh
- [ ] Add a regression check in `tests/test_build.sh` that asserts `jobs/build.sh` sources the common library before execution.
  Verification: make test
