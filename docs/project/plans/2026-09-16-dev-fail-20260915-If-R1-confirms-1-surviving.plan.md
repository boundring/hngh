<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-16 - dev-fail-20260915-If-R1-confirms-1-surviving (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the research line on Make failure-line format and recursive error extraction by adding a parser utility to hngh-automation that tolerates optional `make[N]:` depth markers.

## Steps

- [ ] Create `lib/make_error_parser.py` with a function that extracts failing targets from GNU Make output, handling both `make:` and `make[N]:` prefixes
  Verification: python3 -c "import sys; sys.path.insert(0,'.'); from lib.make_error_parser import extract_failing_targets; assert extract_failing_targets('make[1]: *** [foo] Error 1') == ['foo']"

- [ ] Add a test file `tests/test_make_error_parser.py` that verifies the parser handles single-level, recursive depth markers, and nested directory entries
  Verification: make test

- [ ] Create `scripts/parse_ci_log.sh` that reads a log file path from `$1`, pipes it through `python3 lib/make_error_parser.py`, and exits non-zero if no failures are found
  Verification: bash -n scripts/parse_ci_log.sh

- [ ] Add a fixture log file `tests/fixtures/sample_recursive_make.log` containing lines with `make[1]:`, `make[2]:`, and `make:` prefixes to serve as test input
  Verification: grep -q "make\[2\]:" tests/fixtures/sample_recursive_make.log
