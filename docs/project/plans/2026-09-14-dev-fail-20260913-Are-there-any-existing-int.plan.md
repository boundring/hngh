<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-14 - dev-fail-20260913-Are-there-any-existing-int (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the research line "Are there any existing integration tests or CI pipelines that already exercise the lib/automation.py bin/hngh boundary, and do they pass with the current implementation?" by adding a synchronous, gateable integration test for the automation boundary to close the gap between deferred overnight harnesses and preventive CI checks.

## Steps

- [ ] Create `tests/integration/test_automation_boundary.sh` that invokes `bin/hngh` via `lib/automation.py` in a dry-run or mock mode to verify the CLI contract is handled without errors.
  Verification: bash -n tests/integration/test_automation_boundary.sh
- [ ] Add a test case to `tests/integration/test_automation_boundary.sh` that asserts the exit code is zero and stdout contains the expected success marker for the corrected CLI contract.
  Verification: grep -q "exit_code" tests/integration/test_automation_boundary.sh
- [ ] Update `Makefile` or `tests/Makefile` to include a target `test-integration` that runs `bash tests/integration/test_automation_boundary.sh`.
  Verification: make test
- [ ] Create `scripts/run_integration_test.sh` that wraps the integration test invocation with timing and logging for CI observability.
  Verification: bash -n scripts/run_integration_test.sh
- [ ] Add a unit test in `tests/unit/test_integration_runner.py` that verifies `scripts/run_integration_test.sh` is executable and contains the correct path to the boundary test.
  Verification: python3 tests/unit/test_integration_runner.py
