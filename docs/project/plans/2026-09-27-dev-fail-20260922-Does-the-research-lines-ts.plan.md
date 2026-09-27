<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-27 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
Implements the cadence-line research for automated digest generation by adding a simple script that validates input data structure before processing.

## Steps

- [ ] Add a validation script that checks input data conforms to expected schema
  Verification: bash -n scripts/validate_input.sh
- [ ] Create a test file that exercises the validation script with sample data
  Verification: make test
- [ ] Add a grep check to confirm new script is tracked in repository
  Verification: git ls-files scripts/validate_input.sh
- [ ] Add a bash syntax check for the validation script
  Verification: bash -n scripts/validate_input.sh
- [ ] Create a sample input file under tests/ for validation testing
  Verification: git ls-files tests/sample_input.json
- [ ] Run make test to confirm all existing tests still pass
  Verification: make test
