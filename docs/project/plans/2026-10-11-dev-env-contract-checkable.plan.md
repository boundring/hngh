<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-11 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `scripts/validate-hngh.sh` that checks the hngh-automation repository for syntax errors in all shell scripts
  Verification: bash -n scripts/validate-hngh.sh

- [ ] Create `tests/test-validate-hngh.sh` that runs `bash -n` against every `.sh` file under `scripts/` and `jobs/`
  Verification: bash tests/test-validate-hngh.sh

- [ ] Add `cadence/validate.sh` that invokes `make test` and exits non-zero on failure
  Verification: bash cadence/validate.sh

- [ ] Update `Makefile` to include `validate-hngh` as a pre-commit hook target that runs `bash scripts/validate-hngh.sh`
  Verification: grep -q "validate-hngh" Makefile

- [ ] Add `dashboard/validate-summary.sh` that reports pass/fail status of `make test` for documentation
  Verification: bash dashboard/validate-summary.sh

- [ ] Commit all changes and verify `make test` passes in the repository
  Verification: make test
