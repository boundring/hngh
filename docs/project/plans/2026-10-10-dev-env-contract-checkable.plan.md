<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-10 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the research line on "cadence job schema validation" by introducing a lightweight shell-based linter for job definition files before execution.

## Steps

- [ ] Create `scripts/validate_jobs.sh` to check syntax of job files in `jobs/`
  Verification: bash -n scripts/validate_jobs.sh

- [ ] Add a call to `scripts/validate_jobs.sh` within `cadence/runner.sh`
  Verification: bash -n cadence/runner.sh

- [ ] Add a unit test in `tests/` that exercises the validation script
  Verification: bash -n tests/test_validate_jobs.sh

- [ ] Run `make test` to confirm no regressions
  Verification: make test

- [ ] Verify `scripts/validate_jobs.sh` is referenced by `cadence/runner.sh`
  Verification: git grep 'validate_jobs' cadence/runner.sh
