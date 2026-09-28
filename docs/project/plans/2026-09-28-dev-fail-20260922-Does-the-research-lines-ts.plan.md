<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-28 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a test harness script that validates cadence job definitions parse correctly
  Verification: bash -n cadence/test-harness.sh && make test

- [ ] Create a job definition template under jobs/ that documents required fields
  Verification: grep -q "required_fields" jobs/template.yaml

- [ ] Add a verification script that checks all new job definitions against the template
  Verification: bash cadence/validate-job.sh

- [ ] Update the dashboard digest to include test harness results
  Verification: grep -q "test-harness" dashboard/digest.md

- [ ] Add a lib utility function for job definition validation
  Verification: node --check lib/job-validator.js && make test

- [ ] Commit all changes and run full test suite to confirm no regressions
  Verification: make test
