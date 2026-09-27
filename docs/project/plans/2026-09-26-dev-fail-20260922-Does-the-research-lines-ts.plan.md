<!-- plan: status=accepted risk=normal accepted=2026-09-27T00:04:46Z -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence runner script that validates job definitions before execution
  Verification: bash -n cadence/validate-jobs.sh

- [ ] Create a test suite for the new cadence validation logic
  Verification: make test

- [ ] Add a dashboard digest entry that reports validation pass/fail counts
  Verification: bash scripts/check-digest-output.sh

- [ ] Write a job template that exercises the validation pipeline end-to-end
  Verification: bash -n jobs/template-validation-job.sh

- [ ] Add a lib helper that parses job definition YAML for schema compliance
  Verification: python3 lib/parse-job-schema.py

- [ ] Commit all changes and run the full test suite to confirm no regressions
  Verification: make test
