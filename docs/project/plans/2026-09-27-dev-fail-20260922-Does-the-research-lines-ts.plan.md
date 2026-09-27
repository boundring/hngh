<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-27 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a job-tracking script that logs completed automation runs to a timestamped file under cadence/
  Verification: bash -n cadence/job-tracker.sh

- [ ] Create a verification helper that confirms job-tracker.sh runs without errors
  Verification: bash cadence/job-tracker.sh && grep -q "completed" cadence/job-tracker.log

- [ ] Add a simple dashboard snippet that displays the last 5 job entries from the tracker
  Verification: bash -n dashboard/job-summary.sh

- [ ] Write a test that validates the dashboard snippet produces output without errors
  Verification: bash tests/test-dashboard.sh

- [ ] Update the Makefile to include the new job-tracker verification in the test suite
  Verification: make test && grep -q "job-tracker" Makefile

- [ ] Document the new cadence/ job-tracker.sh in a README under cadence/
  Verification: grep -q "job-tracker" cadence/README.md
