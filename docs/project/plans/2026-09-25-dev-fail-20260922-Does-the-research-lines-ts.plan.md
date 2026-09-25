<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-25 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job script that generates a weekly automation status report from existing job outputs
  Verification: bash -n jobs/weekly-status-report.sh

- [ ] Create a verification script that confirms the report script runs without errors
  Verification: bash jobs/weekly-status-report.sh && echo "SUCCESS"

- [ ] Add a test case that validates the report output contains expected job identifiers
  Verification: bash tests/test-weekly-report.sh

- [ ] Update the cadence configuration to include the new weekly report job
  Verification: grep -q "weekly-status-report" cadence/jobs.yaml

- [ ] Run the full test suite to confirm no regressions from the new job additions
  Verification: make test
