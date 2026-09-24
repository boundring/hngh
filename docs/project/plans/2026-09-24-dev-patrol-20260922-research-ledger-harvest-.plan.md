<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-24 - dev-patrol-20260922-research-ledger-harvest- (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence helper that validates job schedule syntax before execution
  Verification: bash -n cadence/schedule-validator.sh

- [ ] Create a test fixture that exercises the cadence helper with valid and invalid inputs
  Verification: make test

- [ ] Wire the cadence helper into the existing job pipeline via a small lib integration
  Verification: bash -n lib/cadence-integration.sh

- [ ] Add a dashboard snippet that reports cadence validation results
  Verification: bash -n dashboard/cadence-report.sh

- [ ] Run full test suite to confirm no regressions from cadence additions
  Verification: make test
