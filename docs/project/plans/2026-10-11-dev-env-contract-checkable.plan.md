<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-11 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job script that validates input data before processing
  Verification: bash -n jobs/validate-input.sh

- [ ] Create a test file that exercises the validation job with sample data
  Verification: make test

- [ ] Add a script that logs validation results to a digest file
  Verification: bash scripts/log-validation-results.sh

- [ ] Update the cadence runner to include the new validation step
  Verification: bash -n cadence/runner-update.sh

- [ ] Add a dashboard snippet showing validation pass rate
  Verification: python3 dashboard/validate-rate.py

- [ ] Run the full test suite to confirm no regressions
  Verification: make test
