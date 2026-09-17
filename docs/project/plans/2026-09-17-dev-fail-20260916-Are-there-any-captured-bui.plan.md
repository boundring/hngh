<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-17 - dev-fail-20260916-Are-there-any-captured-bui (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the research line "Are there any captured build logs from `hngh`'s CI runs available in the repository (e.g., in an `artifacts/` or `logs/` directory) that demonstrate actual recursive make error lines?" by creating a local, reproducible fixture and verification script to establish the evidentiary bar for recursive make errors without relying on external CI artifacts.

## Steps

- [ ] Create a minimal test Makefile structure in `tests/fixtures/recursive-make/` with a parent `Makefile` invoking `make -C subdir` and a child `subdir/Makefile` containing a failing rule to generate recursive error output.
  Verification: `test -f tests/fixtures/recursive-make/Makefile && test -f tests/fixtures/recursive-make/subdir/Makefile`

- [ ] Add a shell script `scripts/check-recursive-make-error.sh` that executes the fixture, captures stdout/stderr, and asserts the presence of `make[1]: Entering directory` and `make[2]: ***` patterns using `grep -q`.
  Verification: `bash -n scripts/check-recursive-make-error.sh`

- [ ] Integrate the new check into the existing test suite by adding a call to `scripts/check-recursive-make-error.sh` within the `test` target of the root `Makefile` or `tests/run-tests.sh`.
  Verification: `grep -q "check-recursive-make-error" Makefile || grep -q "check-recursive-make-error" tests/run-tests.sh`

- [ ] Execute the full test suite to ensure the new fixture and script pass without breaking existing functionality, confirming the recursive error pattern is correctly detected.
  Verification: `make test`
