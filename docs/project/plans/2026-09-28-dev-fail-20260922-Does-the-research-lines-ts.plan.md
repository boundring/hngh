<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-28 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new cadence job script that runs a lightweight health check on the automation pipeline
  Verification: bash -n cadence/health-check.sh

- [ ] Create a verification script that confirms the new cadence job integrates with the existing test harness
  Verification: make test

- [ ] Add a test case that validates the cadence job output format matches expected schema
  Verification: bash tests/test-cadence-output.sh

- [ ] Update the dashboard digest to include the new health check status
  Verification: grep -q "health-check" dashboard/digest-template.txt

- [ ] Run the full test suite to confirm no regressions from the new cadence integration
  Verification: make test
