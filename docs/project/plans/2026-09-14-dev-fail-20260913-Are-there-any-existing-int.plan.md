<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-14 - dev-fail-20260913-Are-there-any-existing-int (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the research line on cadence beat latency and missing timeout/max_tokens guards by adding a synchronous, bounded integration check for the lib/automation.py ↔ bin/hngh boundary.

## Steps

- [ ] Add an executable shell script at `tests/integration/test_automation_boundary.sh` that invokes `bin/hngh` with a minimal safe argument set and asserts exit code 0.
  Verification: bash -n tests/integration/test_automation_boundary.sh
- [ ] Extend `tests/integration/test_automation_boundary.sh` to wrap the `bin/hngh` invocation in a `timeout 10` guard and assert that the process terminates within the bound.
  Verification: grep -q "timeout 10" tests/integration/test_automation_boundary.sh
- [ ] Add a Python stdlib-only helper at `tests/integration/check_wall_s.py` that parses a supplied elapsed-seconds value and exits non-zero if it exceeds a threshold.
  Verification: python3 tests/integration/check_wall_s.py --help
- [ ] Wire the new integration script into the existing test entrypoint by appending its invocation to `tests/run_tests.sh`.
  Verification: grep -q "tests/integration/test_automation_boundary.sh" tests/run_tests.sh
- [ ] Run the full repository test suite to confirm the new integration check passes and no regressions are introduced.
  Verification: make test
