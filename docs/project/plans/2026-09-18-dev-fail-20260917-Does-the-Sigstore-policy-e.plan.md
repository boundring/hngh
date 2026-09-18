<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-18 - dev-fail-20260917-Does-the-Sigstore-policy-e (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line for robustifying the `hngh` automation pipeline by introducing idempotent state tracking and fail-fast validation logic within the existing job execution framework.

## Steps

- [ ] Create `lib/state.sh` to define a function that writes a timestamped marker file to `[redacted path] using standard shell redirection.
  Verification: bash -n lib/state.sh

- [ ] Add a `precheck` block in `jobs/run.sh` that sources `lib/state.sh` and exits with code 1 if the marker file is older than 24 hours.
  Verification: make test

- [ ] Implement `scripts/validate_config.py` using only `os` and `sys` to verify that required environment variables are present before job execution.
  Verification: python3 scripts/validate_config.py

- [ ] Update `cadence/schedule.sh` to invoke `scripts/validate_config.py` via subprocess before triggering any downstream tasks.
  Verification: bash -n cadence/schedule.sh

- [ ] Add a test case in `tests/test_state.sh` that asserts the exit code is non-zero when the state marker file is missing.
  Verification: make test
