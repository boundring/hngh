<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a validation script that checks job file syntax before execution
  Verification: bash -n scripts/validate-job.sh

- [ ] Create a test that verifies job file structure compliance
  Verification: make test

- [ ] Add a cadence helper that logs job completion timestamps
  Verification: bash scripts/cadence-helper.sh

- [ ] Update the dashboard to display job status from test results
  Verification: make test

- [ ] Add a grep check to ensure no credentials leak into job files
  Verification: grep -r "password\|secret\|token" jobs/ scripts/ cadence/ lib/ tests/

- [ ] Commit all changes and run full test suite to confirm no regressions
  Verification: make test
