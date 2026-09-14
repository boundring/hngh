<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-14 - dev-fail-20260913-Are-there-any-existing-int (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the research line on cadence beat latency by adding a synchronous, bounded integration test that exercises the lib/automation.py ↔ bin/hngh boundary with explicit timeout and max_tokens guards to prevent unguarded model-leg drift.

## Steps

- [ ] Add a new integration test script `tests/integration/test_automation_boundary.sh` that invokes `bin/hngh` via `lib/automation.py` using a mock or stubbed model endpoint, asserting clean exit code 0 and verifying the corrected CLI contract is handled without errors.
  Verification: bash -n tests/integration/test_automation_boundary.sh

- [ ] Modify `cadence/hour/33-research-beat.sh` to wrap the model invocation with an explicit `timeout` command (e.g., `timeout 60`) and add a `--max-tokens` flag to the model call, ensuring `wall_s` measurement brackets only the guarded model leg.
  Verification: grep -q "timeout" cadence/hour/33-research-beat.sh && grep -q -- "--max-tokens" cadence/hour/33-research-beat.sh

- [ ] Update `lib/automation.py` to expose a configurable `MAX_WALL_S` constant (default 60) and pass it as the timeout value when invoking model-dependent subprocesses, ensuring downstream conformance with the corrected CLI contract.
  Verification: python3 -c "import sys; sys.path.insert(0, 'lib'); import automation; assert hasattr(automation, 'MAX_WALL_S')"

- [ ] Add a unit test `tests/unit/test_automation_timeout.py` that verifies `lib/automation.py` correctly passes the timeout parameter to subprocess calls and handles timeout exceptions gracefully without crashing.
  Verification: python3 tests/unit/test_automation_timeout.py

- [ ] Create a CI gate script `scripts/ci-gate.sh` that runs `make test` and explicitly executes `tests/integration/test_automation_boundary.sh`, failing the build if either step returns non-zero, converting overnight harness coverage into a blocking pre-merge check.
  Verification: bash -n scripts/ci-gate.sh && grep -q "make test" scripts/ci-gate.sh

- [ ] Update `Makefile` to add a `test-integration` target that invokes `scripts/ci-gate.sh`, ensuring the new boundary tests are included in the standard test suite gated by `make test`.
  Verification: make test
