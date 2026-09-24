<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-24 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence helper script that validates job output structure
  Verification: bash -n cadence/validate-job-output.sh

- [ ] Create a test that exercises the cadence helper against a sample job
  Verification: make test

- [ ] Add a dashboard digest template for automation status reporting
  Verification: bash -n dashboard/digest-template.sh

- [ ] Update lib/automation-core to import the new cadence helper
  Verification: bash -n lib/automation-core/

- [ ] Run the full test suite to confirm no regressions
  Verification: make test
