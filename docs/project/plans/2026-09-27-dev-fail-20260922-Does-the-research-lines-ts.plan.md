<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-27 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence script that validates job output format
  Verification: bash -n cadence/validate-job-output.sh

- [ ] Add a test for the new cadence validation script
  Verification: make test

- [ ] Add a dashboard digest that reports cadence validation results
  Verification: bash -n dashboard/digest-cadence-results.sh

- [ ] Add lib helper for parsing job output
  Verification: bash -n lib/parse-job-output.py

- [ ] Add tests for lib helper
  Verification: make test

- [ ] Add a script that runs cadence validation before job submission
  Verification: bash -n scripts/pre-job-validate.sh
