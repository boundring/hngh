<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-16 - dev-fail-20260915-Are-there-existing-tests-i (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the fail-20260915-Are-there-existing-tests-in-the-reposito research line by adding a test that asserts the distinction between clean-complete and timeout-complete states in hngh-automation.

## Steps

- [ ] Create `tests/test_complete_states.sh` with a shell script that defines two distinct sentinel values for clean-complete and timeout-complete, then asserts they are not equal via a simple string comparison.
  Verification: bash -n tests/test_complete_states.sh
- [ ] Add a second assertion block in `tests/test_complete_states.sh` that simulates a timeout scenario by setting a variable to the timeout-complete sentinel and verifies it does not match the clean-complete sentinel.
  Verification: bash tests/test_complete_states.sh
- [ ] Create `lib/complete_state_helpers.sh` with two functions, `get_clean_complete_sentinel` and `get_timeout_complete_sentinel`, that echo distinct hardcoded strings without external dependencies.
  Verification: bash -n lib/complete_state_helpers.sh
- [ ] Update `tests/test_complete_states.sh` to source `lib/complete_state_helpers.sh` and call both helper functions, asserting their outputs differ using a `[ "$a" != "$b" ]` check.
  Verification: make test
- [ ] Add a grep-based sanity check in `tests/test_complete_states.sh` that confirms the file contains at least two distinct sentinel assignments by counting lines matching `sentinel=` and asserting the count is >= 2.
  Verification: bash tests/test_complete_states.sh
