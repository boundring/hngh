<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-15 - dev-fail-20260917-overnight-plan-accept-bloc (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a job-cadence validation script that checks all jobs/ entries have required metadata fields
  Verification: bash scripts/validate-cadence.sh

- [ ] Create a test suite for cadence validation in tests/ directory
  Verification: make test

- [ ] Add a dashboard digest entry that reports cadence validation results
  Verification: bash -n dashboard/digest-cadence-report.sh

- [ ] Update lib/ to include cadence validation helper functions
  Verification: node --check lib/cadence-helpers.js

- [ ] Add a script to prune stale cadence entries older than 30 days
  Verification: bash scripts/prune-cadence.sh

- [ ] Verify all new scripts pass syntax checks and tests pass
  Verification: make test
