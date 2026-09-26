<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job script that validates hngh-automation test suite integrity
  Verification: bash -n jobs/test-suite-validator.sh

- [ ] Create a cadence job that runs make test and logs results to dashboard
  Verification: bash -n cadence/test-runner.sh

- [ ] Add a lib utility function for safe file diffing before commits
  Verification: bash -n lib/safe-diff.sh

- [ ] Update tests to include verification of new job script outputs
  Verification: make test

- [ ] Add a digest job that summarizes test pass/fail state
  Verification: bash -n digest/test-summary.sh

- [ ] Verify all new scripts pass syntax checks and integrate with existing workflow
  Verification: bash -n jobs/test-suite-validator.sh && bash -n cadence/test-runner.sh && bash -n lib/safe-diff.sh && bash -n digest/test-summary.sh
