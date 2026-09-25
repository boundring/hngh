<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-25 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job script that validates hngh-automation test suite integrity
  Verification: bash scripts/validate-test-suite.sh

- [ ] Create a cadence tracking script to log daily build status
  Verification: bash cadence/log-builds.sh

- [ ] Update lib/utils.sh with a new helper function for test result parsing
  Verification: bash -n lib/utils.sh

- [ ] Add a dashboard digest script that summarizes recent test outcomes
  Verification: bash dashboard/digest-recent-tests.sh

- [ ] Extend tests/ directory with a regression test for the new job script
  Verification: make test

- [ ] Add a verification script that confirms all new paths are under allowed directories
  Verification: bash scripts/check-path-constraints.sh
