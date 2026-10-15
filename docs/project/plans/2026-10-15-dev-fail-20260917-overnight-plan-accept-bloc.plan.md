<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-15 - dev-fail-20260917-overnight-plan-accept-bloc (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new test script that validates hngh-automation job definitions parse correctly
  Verification: python3 scripts/validate_jobs.py

- [ ] Create a cadence script that generates a weekly digest of automation test results
  Verification: bash cadence/weekly_digest.sh

- [ ] Add a lib utility function for safe job name generation
  Verification: bash -n lib/job_utils.sh

- [ ] Create a test case that verifies job name generation follows naming conventions
  Verification: make test

- [ ] Add a dashboard script that aggregates test pass rates from recent runs
  Verification: bash dashboard/aggregate_tests.sh

- [ ] Create a script that prunes stale test artifacts older than 30 days
  Verification: bash scripts/prune_artifacts.sh
