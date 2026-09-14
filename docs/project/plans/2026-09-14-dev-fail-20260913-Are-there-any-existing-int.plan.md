<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-14 - dev-fail-20260913-Are-there-any-existing-int (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the research line "Are there any existing integration tests or CI pipelines that already exercise the lib/automation.py bin/hngh boundary" by adding a synchronous, blocking integration test to the hngh-automation test suite. This addresses the gap identified in the findings where only deferred overnight harnesses exist, ensuring the boundary is gated by `make test` before merge.

## Steps

- [ ] Create `tests/integration_test_boundary.sh` containing a shell script that invokes `bin/hngh` with a minimal payload and asserts exit code 0.
  Verification: bash -n tests/integration_test_boundary.sh
- [ ] Add the new integration test to the existing test execution logic in `Makefile` or `scripts/run_tests.sh` so it is executed by `make test`.
  Verification: grep -q "integration_test_boundary" Makefile || grep -q "integration_test_boundary" scripts/run_tests.sh
- [ ] Execute `make test` to verify the new integration test passes and does not break existing unit tests.
  Verification: make test
- [ ] Verify that the integration test specifically exercises the `lib/automation.py` module by checking for its import or invocation in the test script.
  Verification: grep -q "automation" tests/integration_test_boundary.sh
