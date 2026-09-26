<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `scripts/validate-plan.sh` helper that checks a development plan file has required sections (rationale + Steps)
  Verification: bash scripts/validate-plan.sh

- [ ] Create `tests/test-plan-validator.sh` to assert the validator script runs without errors
  Verification: bash -n tests/test-plan-validator.sh

- [ ] Add `cadence/plan-check` entry to the cadence directory as a placeholder for future plan validation hooks
  Verification: git grep -c "plan-check" cadence/

- [ ] Update `make test` to include the new plan validator in the test suite
  Verification: make test

- [ ] Document the new validator in `dashboard/README.md` with usage instructions
  Verification: bash -n dashboard/README.md
