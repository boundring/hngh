<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-11 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence runner script that validates job definitions before execution
  Verification: bash scripts/cadence/validate-jobs.sh

- [ ] Update the dashboard to surface job validation results in a new status column
  Verification: bash -n dashboard/status-column.patch

- [ ] Extend tests to cover the new validation script with three edge cases
  Verification: make test

- [ ] Add a digest entry template for cadence validation failures
  Verification: bash scripts/digest/validate-template.sh

- [ ] Commit all changes and run the full test suite to confirm no regressions
  Verification: make test
