<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-28 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence scheduler script that tracks job completion timestamps
  Verification: bash -n scripts/cadence-tracker.sh

- [ ] Create a test that validates cadence tracking output format
  Verification: make test

- [ ] Add a dashboard digest job that summarizes cadence metrics
  Verification: bash -n jobs/digest-cadence-summary.sh

- [ ] Verify all new scripts pass syntax checks
  Verification: bash -n scripts/cadence-tracker.sh && bash -n jobs/digest-cadence-summary.sh

- [ ] Run full test suite to confirm no regressions
  Verification: make test
