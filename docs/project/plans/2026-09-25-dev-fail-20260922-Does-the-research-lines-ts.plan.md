<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-25 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new test script for cadence job validation
  Verification: bash -n cadence/test-job-validation.sh && make test

- [ ] Create a dashboard digest template for automation status
  Verification: bash -n dashboard/digest-automation-status.sh && make test

- [ ] Update lib/automation-runner to support new test integration
  Verification: bash -n lib/automation-runner.sh && make test

- [ ] Add verification script for jobs directory structure
  Verification: bash jobs/verify-structure.sh && make test

- [ ] Create cadence step for automated plan synthesis
  Verification: bash -n cadence/plan-synthesis-step.sh && make test

- [ ] Add tests/ directory entry for new automation tests
  Verification: bash tests/run-automation-tests.sh && make test
