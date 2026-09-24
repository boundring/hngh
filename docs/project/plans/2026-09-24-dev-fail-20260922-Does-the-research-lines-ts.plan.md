<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-24 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a job script that validates configuration syntax
  Verification: bash -n jobs/validate-config.sh

- [ ] Create a test that exercises the validation script
  Verification: make test

- [ ] Add a cadence helper that checks job dependencies
  Verification: bash -n cadence/check-deps.sh

- [ ] Update the main test suite to include new validation tests
  Verification: make test

- [ ] Add documentation for the new validation workflow
  Verification: bash -n jobs/validate-config.sh

- [ ] Verify all new scripts pass syntax checks
  Verification: bash -n jobs/validate-config.sh && bash -n cadence/check-deps.sh
