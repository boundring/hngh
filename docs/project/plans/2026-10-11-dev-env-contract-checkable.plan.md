<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-11 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `scripts/validate-cadence.sh` helper that checks cadence rule files parse without errors
  Verification: bash scripts/validate-cadence.sh && bash -n scripts/validate-cadence.sh

- [ ] Create `cadence/validate-rules.py` to lint cadence rule definitions before they enter the pipeline
  Verification: python3 cadence/validate-rules.py && python3 -c "import ast; ast.parse(open('cadence/validate-rules.py').read())"

- [ ] Update `make test` to include cadence validation in the pre-commit gate
  Verification: make test

- [ ] Add `tests/test-cadence-validation.py` covering edge cases for rule parsing
  Verification: python3 tests/test-cadence-validation.py

- [ ] Document the new validation flow in `dashboard/docs/cadence-validation.md`
  Verification: grep -q "cadence-validation" dashboard/docs/cadence-validation.md
