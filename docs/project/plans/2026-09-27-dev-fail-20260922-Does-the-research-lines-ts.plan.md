<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-27 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a validation script that checks hngh-automation job definitions parse correctly
  Verification: bash -n jobs/validate-hngh-jobs.sh
- [ ] Create a test script that runs the validation against existing job files
  Verification: bash tests/test-hngh-job-validation.sh
- [ ] Add a grep check to confirm no provider credentials leak into job templates
  Verification: grep -r "provider\|credential" jobs/ scripts/ --include="*.sh" --include="*.yml" | wc -l
- [ ] Update the cadence runner to invoke the validation before job execution
  Verification: make test
- [ ] Add a simple dashboard snippet that reports validation pass/fail status
  Verification: bash -n dashboard/report-validation-status.sh
- [ ] Commit all changes and run full test suite to confirm no regressions
  Verification: make test
