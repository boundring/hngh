<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-25 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new automation job under jobs/ that runs a simple health check script
  Verification: bash -n jobs/health-check.sh

- [ ] Create a verification script under scripts/ that validates the health check output
  Verification: bash scripts/validate-health.sh

- [ ] Add a test case under tests/ that exercises the new automation job
  Verification: make test

- [ ] Update the cadence configuration under cadence/ to include the new job
  Verification: grep -q "health-check" cadence/schedule.yaml

- [ ] Add a dashboard snippet under dashboard/ that displays health check status
  Verification: bash -n dashboard/health-widget.js

- [ ] Run the full test suite to confirm no regressions
  Verification: make test
