<!-- plan: status=accepted risk=normal accepted=2026-10-14T00:05:44Z -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-12 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence script that validates job definitions before execution
  Verification: bash -n jobs/validate-job.sh && make test

- [ ] Create a test fixture for job definition validation
  Verification: bash tests/test-validate-job.sh && make test

- [ ] Update cadence runner to invoke validation before job dispatch
  Verification: bash -n cadence/runner-update.sh && make test

- [ ] Add a dashboard digest entry for validation pass rate
  Verification: bash -n dashboard/digest-validate.sh && make test

- [ ] Commit all changes and run full test suite
  Verification: make test
