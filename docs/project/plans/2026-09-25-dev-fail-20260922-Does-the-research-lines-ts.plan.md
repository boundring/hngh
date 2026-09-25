<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-25 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a validation script in scripts/ that checks hngh-automation structure integrity
  Verification: bash -n scripts/validate_structure.sh

- [ ] Add a test case in tests/ that exercises the validation script
  Verification: make test

- [ ] Add a cadence entry in cadence/ that references the validation script
  Verification: grep -r "validate_structure" cadence/

- [ ] Add a dashboard snippet in dashboard/ that displays validation status
  Verification: bash -n dashboard/validation_status.sh

- [ ] Add a lib utility in lib/ that provides the core validation logic
  Verification: node --check lib/validation_utils.js

- [ ] Add a digest entry in digest/ that captures validation results
  Verification: grep -r "validation" digest/
