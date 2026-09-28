<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-28 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence helper script that validates job file syntax before execution
  Verification: bash -n cadence/check-job-syntax.sh

- [ ] Create a test that runs the cadence helper against a sample job file
  Verification: make test

- [ ] Add a dashboard digest script that logs job completion status
  Verification: bash -n dashboard/digest-job-status.sh

- [ ] Extend the test suite to cover the new digest script
  Verification: make test

- [ ] Add a lib utility for safe file pruning with dry-run mode
  Verification: bash -n lib/prune-safe.sh

- [ ] Verify all new scripts pass syntax checks and tests together
  Verification: make test
