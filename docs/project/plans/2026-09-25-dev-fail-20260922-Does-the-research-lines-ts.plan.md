<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-25 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `scripts/validate-input.sh` helper that checks required fields in a job manifest
  Verification: `bash -n scripts/validate-input.sh`

- [ ] Add a `tests/test_validate-input.sh` that exercises the helper with valid and invalid inputs
  Verification: `bash tests/test_validate-input.sh`

- [ ] Add a `cadence/run-validation.sh` entry that invokes the helper before job execution
  Verification: `bash -n cadence/run-validation.sh`

- [ ] Update `Makefile` to include the new validation script in the test suite
  Verification: `make test`
