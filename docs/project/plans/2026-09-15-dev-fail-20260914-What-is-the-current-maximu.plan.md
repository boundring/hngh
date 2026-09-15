<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-15 - dev-fail-20260914-What-is-the-current-maximu (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line `fail-20260915-Are-there-existing-tests-in-the-reposito` by establishing a testable distinction between clean-complete and timeout-complete states in the beat script's state model, closing the untested gap identified in the adopted findings.

## Steps

- [ ] Create `lib/state_markers.py` defining a stdlib-only module with constants `CLEAN_COMPLETE = "clean_complete"` and `TIMEOUT_COMPLETE = "timeout_complete"`, plus a function `classify_state(status: str) -> bool` that returns True only if status equals `CLEAN_COMPLETE`.
  Verification: python3 -c "from lib.state_markers import classify_state; assert classify_state('clean_complete') is True; assert classify_state('timeout_complete') is False"

- [ ] Create `tests/test_state_markers.py` containing a stdlib-only test script that imports `lib.state_markers`, asserts `classify_state("clean_complete")` is True, asserts `classify_state("timeout_complete")` is False, and asserts `classify_state("in_progress")` is False.
  Verification: python3 tests/test_state_markers.py

- [ ] Create `scripts/verify_state_distinction.sh` that runs `python3 -c "from lib.state_markers import classify_state; assert classify_state('clean_complete') != classify_state('timeout_complete')"` and exits with status 0 on success.
  Verification: bash scripts/verify_state_distinction.sh

- [ ] Add a `test-state-distinction` target to the existing Makefile that executes `bash scripts/verify_state_distinction.sh`, ensuring the distinction is gated by `make test`.
  Verification: make test
