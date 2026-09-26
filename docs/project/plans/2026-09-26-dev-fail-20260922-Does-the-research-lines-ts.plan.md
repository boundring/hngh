<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a validation helper script that checks automation job output format compliance
  Verification: bash -n scripts/validate-job-output.sh && make test

- [ ] Create a test fixture that generates a sample job output for validation testing
  Verification: bash -n tests/fixtures/sample-job-output.sh && make test

- [ ] Integrate validation script into cadence job completion check
  Verification: bash -n cadence/job-completion-check.sh && make test

- [ ] Add a dashboard digest entry documenting the new validation workflow
  Verification: grep -q "validation" dashboard/digest/workflow-log.md && make test

- [ ] Update lib/automation-config to reference the new validation script path
  Verification: grep -q "validate-job-output" lib/automation-config.sh && make test

- [ ] Run full test suite to confirm no regressions from new validation integration
  Verification: make test
