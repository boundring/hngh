<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-22 - dev-patrol-20260916-automation-gate-gate-sta (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the ground-truth pass on byte-level serialization invariants (synth-2026-09-20-1) by codifying the verified UTC normalization and s-expression line format into a standalone, stdlib-only validation script for hngh-automation.

## Steps

- [ ] Create `scripts/validate-record-format.py` implementing a pure-Python parser that asserts input lines are valid s-expressions and that any timestamp field matches the strict `YYYY-MM-DDTHH:MM:SSZ` regex.
  Verification: python3 scripts/validate-record-format.py --help
- [ ] Add `tests/test-validate-record-format.sh` containing three inline test cases (valid record, invalid JSON line, malformed timestamp) that invoke the new script and assert exit codes.
  Verification: bash -n tests/test-validate-record-format.sh
- [ ] Integrate the format validator into the existing test suite by appending a call to `tests/test-validate-record-format.sh` at the end of `make test`'s primary test driver script.
  Verification: make test
- [ ] Document the serialization invariants (s-expression lines, UTC fixed-width timestamps) in `docs/serialization-invariants.md` with references to the verified kernel source lines.
  Verification: grep -q "YYYY-MM-DDTHH:MM:SSZ" docs/serialization-invariants.md
