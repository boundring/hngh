<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-16 - dev-fail-20260914-Which-artifact-records-the (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line "Does the beat script's state model distinguish between 'timeout-complete' and 'in-progress' markers, and if not, what is the minimal patch to close this gap?" by establishing a distinct `timeout_complete` status token in the hngh-automation state model and adding test coverage that asserts its distinction from clean-complete states.

## Steps

- [ ] Define a `timeout_complete` status constant in `lib/state.py` alongside existing completion markers
  Verification: grep -q "timeout_complete" lib/state.py && python3 -c "from lib.state import timeout_complete; print(timeout_complete)"
- [ ] Update the beat finalization logic in `scripts/beat.py` to emit `timeout_complete` when a deadline expires without clean completion
  Verification: bash -n scripts/beat.py && grep -q "timeout_complete" scripts/beat.py
- [ ] Add a test case in `tests/test_state_distinction.py` asserting that `timeout_complete` is not equal to `clean_complete` and is distinct from `in_progress`
  Verification: python3 tests/test_state_distinction.py
- [ ] Update the reconciliation handler in `cadence/reconcile.py` to recognize `timeout_complete` as a non-terminal state eligible for retry
  Verification: bash -n cadence/reconcile.py && grep -q "timeout_complete" cadence/reconcile.py
- [ ] Run the full test suite to confirm no regressions in existing state transitions
  Verification: make test
