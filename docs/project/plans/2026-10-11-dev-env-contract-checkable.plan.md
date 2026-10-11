<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-11 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Rationale: Implements the 'job-syntax-gating' research line by introducing a pre-integration validation script that ensures all new automation jobs pass bash syntax checks before being merged into the repository.

## Steps

- [ ] Create a validation script at `scripts/check-job-syntax.sh` that iterates over `jobs/` and runs `bash -n` on each file to catch syntax errors.
  Verification: bash -n scripts/check-job-syntax.sh
- [ ] Add a test case in `tests/test-job-syntax.sh` that invokes the validation script against a known-good job file to confirm it returns success.
  Verification: bash tests/test-job-syntax.sh
- [ ] Confirm the validation script integrates with the existing test suite without breaking the standard test target.
  Verification: make test
