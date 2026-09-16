<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-16 - dev-fail-20260915-If-R1-confirms-1-surviving (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the research line on locating the canonical verdict rule and its embedded CI copy by adding a hermetic test that pins both file paths and asserts their contents match, closing the unresolved drift question.

## Steps

- [ ] Create `tests/test_verdict_rule_drift.py` with a stdlib-only script that reads the kernel-side verdict rule file and the hngh-automation CI workflow file, then asserts their embedded rule text is byte-identical.
  Verification: python3 tests/test_verdict_rule_drift.py

- [ ] Add a `make test` target entry or existing test runner invocation in `Makefile` (or `tests/Makefile`) that executes `python3 tests/test_verdict_rule_drift.py` so the drift check is gated by the standard test suite.
  Verification: grep -q "test_verdict_rule_drift" Makefile

- [ ] Create `scripts/check_verdict_paths.sh` that verifies the two exact file paths exist in the repository tree and prints their SHA256 hashes for auditability.
  Verification: bash -n scripts/check_verdict_paths.sh

- [ ] Add a step to `Makefile` test target or `tests/` runner that invokes `bash scripts/check_verdict_paths.sh` to confirm path existence before content comparison.
  Verification: grep -q "check_verdict_paths" Makefile

- [ ] Run the full test suite to confirm the new drift check and path verification pass without breaking existing tests.
  Verification: make test
