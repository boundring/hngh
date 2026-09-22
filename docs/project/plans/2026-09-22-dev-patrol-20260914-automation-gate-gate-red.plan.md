<!-- plan: status=accepted risk=normal accepted=2026-09-22T13:03:06Z -->
# 2026-09-22 - dev-patrol-20260914-automation-gate-gate-red (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the byte-level serialization invariants research line (synth-2026-09-20-1) by adding a standalone verification script that asserts the UTC timestamp format and s-expression record structure without modifying kernel sources.

## Steps

- [ ] Create `scripts/verify-serialization-invariants.py` containing a Python 3 stdlib-only script that defines a sample record dict, serializes it to an s-expression string, and asserts the timestamp field matches the regex `\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z`.
  Verification: python3 scripts/verify-serialization-invariants.py

- [ ] Add a test case to `tests/test_serialization_invariants.sh` that invokes the new script and captures its exit code, ensuring it passes on valid input.
  Verification: bash -n tests/test_serialization_invariants.sh

- [ ] Extend `scripts/verify-serialization-invariants.py` to include a negative test block that asserts an invalid timestamp format (e.g., missing 'Z') causes the script to exit with a non-zero status.
  Verification: python3 scripts/verify-serialization-invariants.py --negative-test

- [ ] Create `cadence/check-serialization.sh` that runs the verification script and greps for "PASS" in its output, exiting non-zero if the pattern is not found.
  Verification: bash -n cadence/check-serialization.sh

- [ ] Update `Makefile` to add a `verify-serialization` target that executes `cadence/check-serialization.sh`, ensuring it is integrated into the standard test workflow.
  Verification: grep -q "verify-serialization" Makefile
