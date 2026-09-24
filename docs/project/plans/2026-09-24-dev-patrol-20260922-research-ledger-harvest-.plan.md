<!-- plan: status=accepted risk=normal accepted=2026-09-24T08:04:02Z -->
# 2026-09-24 - dev-patrol-20260922-research-ledger-harvest- (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a job-scheduling helper script under scripts/ that validates cadence configuration syntax before execution
  Verification: bash -n scripts/cadence-validator.sh

- [ ] Create a test script under tests/ that exercises the cadence-validator.sh helper with valid and invalid inputs
  Verification: bash tests/cadence-validator-tests.sh

- [ ] Update the Makefile test target to include the new cadence-validator test suite
  Verification: make test

- [ ] Add a dashboard digest entry under digest/ that documents the cadence-validator addition for team visibility
  Verification: grep -q "cadence-validator" digest/CHANGELOG.md

- [ ] Verify all new scripts pass bash syntax checks and integrate cleanly with existing test pipeline
  Verification: make test && bash -n scripts/cadence-validator.sh && bash tests/cadence-validator-tests.sh
