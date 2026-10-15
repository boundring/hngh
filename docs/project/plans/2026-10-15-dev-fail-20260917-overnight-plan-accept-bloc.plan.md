<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-15 - dev-fail-20260917-overnight-plan-accept-bloc (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence job that validates automation script syntax before execution
  Verification: bash -n cadence/validate-syntax.sh

- [ ] Create a helper script to lint all automation scripts in jobs/
  Verification: bash scripts/lint-jobs.sh

- [ ] Add a test that confirms linting passes for existing scripts
  Verification: make test

- [ ] Document the validation workflow in cadence/README.md
  Verification: grep -q "validation" cadence/README.md

- [ ] Verify all new scripts pass syntax checks
  Verification: bash -n jobs/*.sh scripts/*.sh cadence/*.sh
