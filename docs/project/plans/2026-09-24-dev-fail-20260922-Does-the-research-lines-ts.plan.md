<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-24 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a syntax-validation script for new job files under jobs/
  Verification: bash -n scripts/validate-job.sh

- [ ] Register the validation script in the cadence test runner
  Verification: make test

- [ ] Add a grep-based check that new commits touch only allowed paths
  Verification: git grep --cached -l 'jobs/' | head -5

- [ ] Create a README note documenting the verification cadence
  Verification: bash scripts/check-readme.sh

- [ ] Add a python3 stdlib script to list recent cadence runs
  Verification: python3 scripts/list-cadence-runs.py

- [ ] Commit all changes and verify no forbidden paths are modified
  Verification: git diff --name-only | grep -vE 'jobs/|scripts/|cadence/|lib/|tests/|dashboard/|digest/'
