<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-14 - dev-fail-20260913-Are-there-any-existing-int (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the research line on cadence beat latency and missing timeout guards by adding a synchronous, bounded integration test that exercises the lib/automation.py ↔ bin/hngh boundary with a mock model call to prevent unguarded wall-time drift.

## Steps

- [ ] Create `tests/integration_test_boundary.sh` that sources `lib/automation.py` helpers and invokes `bin/hngh` with a mocked model response, asserting exit code 0 and output contains "boundary-ok".
  Verification: bash -n tests/integration_test_boundary.sh
- [ ] Add a timeout guard to the test script using `timeout 10s` around the `bin/hngh` invocation to ensure it fails fast if the boundary hangs.
  Verification: grep -q "timeout 10s" tests/integration_test_boundary.sh
- [ ] Update `makefile` or existing test runner to include `tests/integration_test_boundary.sh` in the standard test suite execution path.
  Verification: grep -q "integration_test_boundary" Makefile
- [ ] Run the full test suite to verify the new integration test passes and does not break existing unit tests.
  Verification: make test
