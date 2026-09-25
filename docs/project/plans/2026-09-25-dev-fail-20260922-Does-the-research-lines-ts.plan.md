<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-25 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a script to validate hngh-automation job definitions before execution
  Verification: bash -n jobs/validate-job.sh

- [ ] Create a test suite for the new job validation script
  Verification: make test

- [ ] Add a cadence entry to run validation on job commits
  Verification: bash cadence/run-validation.sh

- [ ] Verify all new scripts pass syntax checks
  Verification: bash -n scripts/validate-job.sh && bash -n cadence/run-validation.sh

- [ ] Ensure no secrets or credentials are introduced
  Verification: grep -r "password\|secret\|token" jobs/ scripts/ cadence/ --include="*.sh" | grep -v "^Binary"

- [ ] Run full test suite to confirm no regressions
  Verification: make test
