<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-16 - dev-fail-20260915-If-R1-confirms-1-surviving (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the research line on make failure-line format and recursive depth markers by adding a parser that tolerates `make[N]:` prefixes for reliable failing-target extraction.

## Steps

- [ ] Create `lib/make_error_parser.py` with a function that extracts target names from lines matching the pattern `^make(\[\d+\])?: \*\*\* \[(.+?)\] Error \d+`.
  Verification: python3 -c "from lib.make_error_parser import extract_targets; assert extract_targets(['make[1]: *** [foo/bar.o] Error 1']) == ['foo/bar.o']"

- [ ] Add a test file `tests/test_make_error_parser.py` that asserts correct extraction for single-level, recursive depth 1, and recursive depth 2 make error lines.
  Verification: python3 tests/test_make_error_parser.py

- [ ] Create `scripts/extract_failing_targets.sh` that pipes input through grep with the pattern `^make\[[0-9]+\]: \*\*\* \[.*Error` to filter only recursive make errors.
  Verification: bash -n scripts/extract_failing_targets.sh

- [ ] Add a test script `tests/test_extract_failing_targets.sh` that verifies the script correctly filters recursive error lines and ignores single-level errors.
  Verification: bash tests/test_extract_failing_targets.sh

- [ ] Update `Makefile` to include a `test` target that runs both Python and shell test files for the parser and extraction script.
  Verification: make test
