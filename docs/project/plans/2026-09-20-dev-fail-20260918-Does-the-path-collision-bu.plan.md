<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-20 - dev-fail-20260918-Does-the-path-collision-bu (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line on **standardizing job execution and verification workflows** by introducing a reusable shell library for common task operations and ensuring all new scripts pass strict syntax validation before integration.

## Steps

- [ ] Create `lib/common.sh` containing helper functions for logging and error handling used by automation jobs.
  Verification: bash -n lib/common.sh

- [ ] Add a new job script `jobs/cleanup_artifacts.sh` that sources `lib/common.sh` to remove temporary build files.
  Verification: bash -n jobs/cleanup_artifacts.sh

- [ ] Implement `scripts/validate_config.py` using only the Python standard library to check for required keys in job configuration files.
  Verification: python3 scripts/validate_config.py

- [ ] Update `cadence/schedule.yaml` to include a new entry for the cleanup job with standard execution parameters.
  Verification: grep -q "cleanup_artifacts" cadence/schedule.yaml

- [ ] Add a test script `tests/test_common.sh` that sources `lib/common.sh` and asserts the presence of the logging function.
  Verification: bash tests/test_common.sh
