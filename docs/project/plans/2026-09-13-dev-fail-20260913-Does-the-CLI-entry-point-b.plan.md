<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-13 - dev-fail-20260913-Does-the-CLI-entry-point-b (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the research line "Does `lib/automation.py` invoke `bin/hngh` via `subprocess` or direct module import?" by establishing a hermetic test seam that verifies the subprocess invocation boundary without modifying kernel sources.

## Steps

- [ ] Create `tests/test_automation_boundary.py` to assert that `lib/automation.py` invokes `bin/hngh` via `subprocess` rather than direct import.
  Verification: make test
- [ ] Add a mock `bin/hngh` executable stub in `tests/fixtures/mock_hngh.sh` that logs its invocation arguments to stdout.
  Verification: bash -n tests/fixtures/mock_hngh.sh
- [ ] Extend `lib/automation.py` to support an environment variable override for the binary path, enabling hermetic test injection.
  Verification: python3 lib/automation.py --help
- [ ] Implement a unit test in `tests/test_automation_boundary.py` that sets the env var to the mock stub and verifies subprocess execution occurs.
  Verification: make test
- [ ] Add a regression check in `tests/test_cli_contract.py` ensuring the corrected CLI contract from 2026-08-25 is handled without errors.
  Verification: make test
