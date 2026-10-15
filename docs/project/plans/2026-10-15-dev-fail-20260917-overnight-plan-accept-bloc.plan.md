<!-- plan: status=accepted risk=normal accepted=2026-10-15T20:07:23Z -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-15 - dev-fail-20260917-overnight-plan-accept-bloc (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence script that validates job definitions against a schema
  Verification: bash -n cadence/validate-jobs.sh && make test

- [ ] Create a lib helper for safe path resolution under jobs/
  Verification: bash -n lib/path-resolver.sh && make test

- [ ] Add a test for the path resolver helper
  Verification: bash tests/test-path-resolver.sh && make test

- [ ] Update dashboard config to reference the new cadence script
  Verification: grep -q 'validate-jobs' dashboard/config.yaml && make test

- [ ] Add a digest script that summarizes cadence validation results
  Verification: bash -n digest/summarize-cadence.sh && make test

- [ ] Verify all new scripts pass syntax checks and tests
  Verification: make test
