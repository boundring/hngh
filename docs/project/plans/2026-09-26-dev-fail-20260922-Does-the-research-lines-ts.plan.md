<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new cadence job script that validates automation pipeline integrity
  Verification: bash -n cadence/validate-pipeline.sh

- [ ] Create a verification helper script to check job completion status
  Verification: bash -n scripts/check-job-status.sh

- [ ] Update the cadence runner to invoke the new validation script
  Verification: make test

- [ ] Add a test case for the new validation pipeline
  Verification: make test

- [ ] Document the new cadence job in the dashboard
  Verification: grep -q "validate-pipeline" dashboard/cadence-docs.md
