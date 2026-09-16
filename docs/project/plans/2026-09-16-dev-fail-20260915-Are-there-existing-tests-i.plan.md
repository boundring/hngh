<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-16 - dev-fail-20260915-Are-there-existing-tests-i (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the research line `fail-20260915-Are-there-existing-tests-in-the-reposito` by establishing a baseline test suite for hngh-automation that asserts on clean-complete versus timeout-complete state distinctions, filling the identified coverage gap.

## Steps

- [ ] Create a shell script at `scripts/check-state-distinction.sh` that defines and validates the exit-code contract for clean-complete (0) and timeout-complete (124) states.
  Verification: bash -n scripts/check-state-distinction.sh
- [ ] Add a unit test file at `tests/test_state_distinction.sh` that sources the check script and asserts the distinct exit codes for both state types.
  Verification: make test
- [ ] Create a fixture directory at `tests/fixtures/state/` containing sample status files representing clean-complete and timeout-complete payloads.
  Verification: grep -q "timeout_complete" tests/fixtures/state/timeout.status
- [ ] Extend the existing test runner in `tests/run.sh` to include the new state distinction test case in its execution sequence.
  Verification: make test
