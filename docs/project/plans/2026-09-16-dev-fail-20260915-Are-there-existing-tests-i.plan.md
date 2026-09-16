<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-16 - dev-fail-20260915-Are-there-existing-tests-i (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the research line `fail-20260915-Are-there-existing-tests-in-the-reposito`, which identifies an untested gap between clean-complete and timeout-complete states in hngh-automation.

## Steps

- [ ] Create a new test file at `tests/test_timeout_complete.sh` that defines a mock state variable set to `timeout_complete` and asserts it is distinct from `clean_complete`.
  Verification: bash -n tests/test_timeout_complete.sh

- [ ] Add a second assertion block in `tests/test_timeout_complete.sh` that verifies the `timeout_complete` state triggers a retry logic path rather than a terminal success path.
  Verification: bash tests/test_timeout_complete.sh

- [ ] Create a helper script at `scripts/check_state_distinction.py` that uses only the Python standard library to parse a sample status file and confirm `timeout_complete` is not mapped to a success exit code.
  Verification: python3 scripts/check_state_distinction.py

- [ ] Integrate the new shell test into the existing test suite by ensuring `make test` includes execution of `tests/test_timeout_complete.sh`.
  Verification: make test
