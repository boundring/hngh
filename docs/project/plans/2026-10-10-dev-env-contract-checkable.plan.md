<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-10 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a utility script that validates input parameters before processing
  Verification: bash -n scripts/validate_params.sh

- [ ] Create a test script that exercises the validation logic
  Verification: python3 tests/test_validate_params.py

- [ ] Update the main automation entry point to call the validation script
  Verification: bash -n jobs/run_pipeline.sh

- [ ] Add a grep check to confirm no hardcoded credentials in new files
  Verification: grep -r "password\|secret\|token" scripts/validate_params.sh tests/test_validate_params.py

- [ ] Run the full test suite to confirm no regressions
  Verification: make test
