<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-16 - dev-fail-20260915-What-are-the-exact-file-pa (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line `fail-20260915-What-make-version-does-the-repo-s-toolch` by creating a robust failure-extraction script that tolerates recursive make invocations (`make[N]: *** [target] Error N`) and verifying its syntax.

## Steps

- [ ] Create the failure extraction script at `scripts/extract_make_failures.sh` with a regex pattern that matches optional recursive depth markers (e.g., `make[0-9]*: \*\*\* \[.*\] Error [0-9]+`) to handle nested make invocations.
  Verification: bash -n scripts/extract_make_failures.sh

- [ ] Add a test fixture file at `tests/fixtures/make_recursive_failure.log` containing sample lines for single-level (`make: *** [target] Error 1`) and recursive (`make[1]: *** [nested/target] Error 2`) make failures.
  Verification: grep -q "make\[1\]: \*\*\* \[nested/target\] Error 2" tests/fixtures/make_recursive_failure.log

- [ ] Create a test script at `tests/test_extract_make_failures.sh` that runs the extraction logic against the fixture file and asserts that both single-level and recursive error lines are captured.
  Verification: bash -n tests/test_extract_make_failures.sh

- [ ] Execute the test script to verify that the extraction logic correctly identifies failing targets from the provided fixture data without relying solely on the literal `make:` prefix.
  Verification: bash tests/test_extract_make_failures.sh
