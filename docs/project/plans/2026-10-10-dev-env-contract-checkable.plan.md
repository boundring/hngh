<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-10 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new cadence job template for hngh-automation test validation
  Verification: bash -n cadence/hngh-automation-test-template.sh

- [ ] Create a verification script that runs make test against the new cadence job
  Verification: bash scripts/validate-cadence-job.sh

- [ ] Add a test case for the new cadence job template in tests/
  Verification: make test

- [ ] Update dashboard configuration to reflect the new cadence job
  Verification: bash -n dashboard/cadence-job-dashboard-config.sh

- [ ] Run full test suite to confirm no regressions from the new cadence job
  Verification: make test
