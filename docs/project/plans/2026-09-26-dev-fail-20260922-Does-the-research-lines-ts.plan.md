<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a shell script that validates job output structure before dashboard ingestion
  Verification: bash -n scripts/validate-job-output.sh

- [ ] Create a test that exercises the validation script against sample job data
  Verification: bash scripts/validate-job-output.sh

- [ ] Add a cadence rule that runs validation before each digest generation
  Verification: grep -q "validate-job-output" cadence/digest-rules.yaml

- [ ] Update the dashboard ingestion step to fail on validation errors
  Verification: grep -q "validate-job-output" jobs/dashboard-ingest.sh

- [ ] Add a git hook that runs validation on pre-commit for automation changes
  Verification: bash -n .git/hooks/pre-commit

- [ ] Document the validation workflow in the project README
  Verification: grep -q "validation" README.md
