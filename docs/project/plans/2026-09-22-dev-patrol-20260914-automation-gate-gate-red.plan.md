<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-22 - dev-patrol-20260914-automation-gate-gate-red (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the ground-truth pass for synth-2026-09-20-1, which verified that hngh records are Common Lisp s-expressions serialized as one form per line with fixed-width UTC timestamps, and confirmed these invariants are already enforced by the kernel writer and tested by the existing filesystem suite.

## Steps

- [ ] Add a shell script under scripts/ that extracts the first record line from a sample journal file and asserts it parses as an s-expression via a minimal Python stdlib check
  Verification: bash -n scripts/check-record-sexpr.sh && python3 scripts/check-record-sexpr.py
- [ ] Create a test fixture directory tests/fixtures/records/ containing one canonical record line in the exact YYYY-MM-DDTHH:MM:SSZ timestamp shape used by format-utc-timestamp
  Verification: grep -q 'T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z' tests/fixtures/records/sample.lisp
- [ ] Write a Python stdlib script under scripts/ that validates the timestamp field in a given record line matches the fixed-width UTC pattern and exits non-zero on mismatch
  Verification: python3 scripts/validate-utc-timestamp.py tests/fixtures/records/sample.lisp
- [ ] Add a make-independent shell test under tests/ that runs the s-expression and timestamp validators against the fixture and confirms both pass
  Verification: bash tests/test-serialization-invariants.sh
- [ ] Commit all new files as plain additions under scripts/, tests/, and tests/fixtures/ with no changes to src/, Makefile, or kernel sources
  Verification: git diff --name-only HEAD~1 | grep -vE '^(src/|Makefile|hngh\.asd)'
