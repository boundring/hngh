<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a test helper script for validating automation output format
  Verification: bash -n jobs/test_helpers/validate_output.sh

- [ ] Create a verification script that checks automation job completion status
  Verification: bash jobs/scripts/check_job_status.sh

- [ ] Update the test suite to include new validation checks
  Verification: make test

- [ ] Add a simple cadence tracking script for monitoring automation progress
  Verification: bash cadence/track_progress.sh

- [ ] Verify all new scripts pass syntax validation
  Verification: bash -n jobs/test_helpers/validate_output.sh && bash -n jobs/scripts/check_job_status.sh && bash -n cadence/track_progress.sh

- [ ] Run full test suite to confirm no regressions
  Verification: make test
