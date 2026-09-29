<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-29 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a validation script under scripts/ that checks job definition files for required fields
  Verification: bash -n scripts/validate-jobs.sh

- [ ] Add a unit test under tests/ that exercises the validation script with a sample job file
  Verification: bash tests/test-validate-jobs.sh

- [ ] Add a cadence entry under cadence/ that runs the validation script on a schedule
  Verification: bash -n cadence/run-validation.sh

- [ ] Run the full test suite to confirm no regressions
  Verification: make test
