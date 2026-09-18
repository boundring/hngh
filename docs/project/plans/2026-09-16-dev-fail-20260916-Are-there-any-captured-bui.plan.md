<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-16 - dev-fail-20260916-Are-there-any-captured-bui (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line `fail-20260916-Are-there-any-captured-build-logs-from-h` by establishing a deterministic, local verification harness that generates and validates recursive make error patterns (e.g., `make[2]: *** Error 1`) within the hngh-automation repository, resolving the unresolved evidentiary gap for CI log artifacts without relying on external host access.

## Steps

- [ ] Create `scripts/verify-make-recursion.sh` containing a bash script that generates a minimal two-level Makefile structure in a temporary directory and executes `make -n` to capture expected recursive error output patterns
  Verification: `bash -n scripts/verify-make-recursion.sh`

- [ ] Add `tests/test_make_recursion_pattern.sh` which sources the verification logic and asserts that the generated make output contains the literal string `make[2]: *** [` using standard bash exit codes
  Verification: `bash tests/test_make_recursion_pattern.sh`

- [ ] Create `lib/make_log_parser.py` implementing a Python stdlib-only parser that validates whether a given log stream meets the minimum evidentiary bar for recursive make failures (checking for `make[1]: Entering` and `make[2]: ***` sequences)
  Verification: `python3 lib/make_log_parser.py --help`

- [ ] Add `tests/test_make_log_parser.py` containing unit tests that feed synthetic log strings to the parser and verify correct classification of recursive vs. single-level make errors
  Verification: `python3 tests/test_make_log_parser.py`

- [ ] Update `Makefile` in hngh-automation to include a `test-make-recursion` target that executes both bash and python verification steps sequentially, ensuring they are gated by the existing test infrastructure
  Verification: `make test`
