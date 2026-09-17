<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-17 - dev-fail-20260916-Are-there-any-captured-bui (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements research line fail-20260916-Are-there-any-captured-build-logs-from-h by adding a local, reproducible fixture and verification script to demonstrate recursive make error lines without relying on external CI artifacts.

## Steps

- [ ] Create `tests/fixtures/recursive-make-failure.log` containing the exact four-line recursive make error excerpt defined in research finding F2.
  Verification: `grep -qF "make[2]: *** [subdir/target.o] Error 1" tests/fixtures/recursive-make-failure.log`

- [ ] Add `scripts/verify-recursive-make-log.sh` that checks for the presence of `make[1]: Entering directory`, `make[2]: ***`, and `make: ***` lines in the fixture file.
  Verification: `bash -n scripts/verify-recursive-make-log.sh`

- [ ] Execute the verification script against the fixture to confirm it passes when the recursive error pattern is present.
  Verification: `bash scripts/verify-recursive-make-log.sh tests/fixtures/recursive-make-failure.log`

- [ ] Add a negative test case in `tests/fixtures/no-recursive-make-failure.log` containing only single-level make errors to ensure the script correctly rejects non-recursive logs.
  Verification: `! bash scripts/verify-recursive-make-log.sh tests/fixtures/no-recursive-make-failure.log`

- [ ] Integrate the recursive make log verification into the existing test suite by adding a call to `scripts/verify-recursive-make-log.sh` in `tests/run-tests.sh`.
  Verification: `make test`
