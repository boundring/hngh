<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-16 - dev-fail-20260915-What-are-the-exact-file-pa (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line `fail-20260915-What-make-version-does-the-repo-s-toolch` by establishing a robust, recursive-aware Make failure extraction pattern and verifying its integration within the hngh-automation CI workflow.

## Steps

- [ ] Create `lib/make_failure_parser.py` implementing a regex that matches GNU Make error lines with optional recursive depth markers (e.g., `make[1]: *** ... Error N`).
  Verification: python3 -c "import sys; sys.path.insert(0, 'lib'); from make_failure_parser import parse_make_errors; assert parse_make_errors('make[1]: *** [target] Error 1\nmake: *** [root] Error 2') == ['target', 'root']"

- [ ] Add a unit test in `tests/test_make_failure_parser.py` that asserts the parser correctly extracts target names from both single-level and recursive make error outputs.
  Verification: make test

- [ ] Locate the embedded verdict rule copy within the CI workflow by searching for Make error handling logic in `jobs/` or `scripts/`.
  Verification: grep -r "Error" jobs/ scripts/ | grep -v "\.pyc"

- [ ] Update the identified CI workflow script to utilize the new `lib/make_failure_parser.py` module for consistent failing-target extraction.
  Verification: bash -n <path_to_updated_script>

- [ ] Verify that no existing tests break due to the refactored error handling logic by running the full test suite.
  Verification: make test
