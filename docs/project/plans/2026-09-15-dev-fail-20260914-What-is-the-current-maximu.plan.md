<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-15 - dev-fail-20260914-What-is-the-current-maximu (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line "Does the beat script's state model distinguish between 'timeout-complete' and 'in-progress' markers, and if not, what is the minimal patch to close this gap?" by adding a distinct status token to the cadence scripts and asserting its presence in tests.

## Steps

- [ ] Add a `TIMEOUT_COMPLETE` status constant or string literal to the state model in `cadence/beat.sh` (or equivalent shell script) to distinguish from clean-complete.
  Verification: grep -q "TIMEOUT_COMPLETE" cadence/beat.sh
- [ ] Update the finalization logic in `cadence/beat.sh` to write the new timeout status token when a deadline expires without completion.
  Verification: bash -n cadence/beat.sh
- [ ] Create a test script in `tests/test_timeout_status.sh` that simulates a timeout scenario and asserts the output contains the distinct timeout marker.
  Verification: bash tests/test_timeout_status.sh
- [ ] Register the new test case in the main test suite entry point (e.g., `tests/run_tests.sh` or `Makefile` test target) to ensure it runs during `make test`.
  Verification: make test
