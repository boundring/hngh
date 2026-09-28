<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-28 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence runner script that executes a single job and reports status
  Verification: bash -n cadence/run-job.sh

- [ ] Create a test that validates the cadence runner script syntax
  Verification: bash cadence/run-job.sh --dry-run

- [ ] Add a dashboard integration test that checks job output format
  Verification: python3 tests/test_dashboard_format.py

- [ ] Update the Makefile test target to include the new cadence test
  Verification: make test

- [ ] Add a lib helper function for job status parsing
  Verification: bash -n lib/job-status.sh

- [ ] Verify all new scripts pass syntax checks
  Verification: bash -n scripts/cadence-runner.sh && bash -n lib/job-status.sh
