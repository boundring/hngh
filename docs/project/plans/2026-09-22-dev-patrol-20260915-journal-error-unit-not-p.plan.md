<!-- plan: status=accepted risk=normal accepted=2026-09-22T13:03:06Z -->
# 2026-09-22 - dev-patrol-20260915-journal-error-unit-not-p (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the byte-level serialization invariants research line (synth-2026-09-20-1) by adding a standalone, stdlib-only Python verification script that asserts the fixed-width UTC timestamp shape and s-expression line format produced by the hngh writer boundary.
## Steps

- [ ] Create `scripts/verify_serialization_invariants.py` implementing a pure-function check for the `YYYY-MM-DDTHH:MM:SSZ` regex and single-form-per-line constraint.
  Verification: python3 scripts/verify_serialization_invariants.py
- [ ] Add a sample fixture file `tests/fixtures/sample_record.txt` containing three valid s-expression lines with correct UTC timestamps.
  Verification: grep -c '^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}Z' tests/fixtures/sample_record.txt
- [ ] Extend the verification script to load and validate the fixture file, exiting non-zero on any line that fails the shape or s-expression parse.
  Verification: python3 scripts/verify_serialization_invariants.py --fixture tests/fixtures/sample_record.txt
- [ ] Add a negative test case in `tests/fixtures/bad_timestamp.txt` with an invalid timezone suffix to ensure the script rejects it.
  Verification: ! python3 scripts/verify_serialization_invariants.py --fixture tests/fixtures/bad_timestamp.txt
