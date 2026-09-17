<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-17 - dev-fail-20260916-Are-there-any-captured-bui (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the research line `fail-20260916-Are-there-any-captured-build-logs-from-h` by establishing a local, reproducible fixture and verification pipeline to demonstrate recursive make error lines without relying on external CI artifacts.

## Steps

- [ ] Create `tests/fixtures/recursive-make-fail/Makefile` that invokes a subdirectory Makefile with `-C subdir` to trigger nested recursion.
  Verification: `test -f tests/fixtures/recursive-make-fail/Makefile && grep -q "subdir" tests/fixtures/recursive-make-fail/Makefile`
- [ ] Create `tests/fixtures/recursive-make-fail/subdir/Makefile` containing a rule that intentionally fails to generate the `make[1]` and `make[2]` error output.
  Verification: `test -f tests/fixtures/recursive-make-fail/subdir/Makefile && grep -q "Error" tests/fixtures/recursive-make-fail/subdir/Makefile`
- [ ] Add `scripts/capture-build-log.sh` that executes the fixture Makefile and redirects stderr to a log file in `tests/artifacts/`.
  Verification: `bash -n scripts/capture-build-log.sh`
- [ ] Extend `make test` target or add a dedicated test step to run `scripts/capture-build-log.sh` and assert the presence of `make[2]: ***` in the generated log.
  Verification: `make test`
- [ ] Add a grep-based assertion script `tests/check-recursive-error.sh` that verifies the captured log contains both `make[1]: Entering directory` and `make[2]: ***` lines.
  Verification: `bash tests/check-recursive-error.sh tests/artifacts/recursive-make-fail.log`
