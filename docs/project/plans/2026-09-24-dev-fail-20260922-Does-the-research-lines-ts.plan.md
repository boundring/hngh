<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-24 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a shell script that validates hngh-automation test output format
  Verification: bash -n scripts/test-output-validator.sh

- [ ] Create a cadence job that runs the test-output-validator on each commit
  Verification: bash -n cadence/run-validator-job.sh

- [ ] Update the main test runner to include the new validator step
  Verification: make test

- [ ] Add a dashboard script that reports validator pass/fail status
  Verification: bash -n dashboard/report-validator-status.sh

- [ ] Verify all new scripts pass syntax checks
  Verification: bash -n scripts/test-output-validator.sh && bash -n cadence/run-validator-job.sh && bash -n dashboard/report-validator-status.sh
