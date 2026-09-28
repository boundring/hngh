<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-28 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a configuration consistency check script under scripts/
  Verification: bash -n scripts/config-consistency-check.sh

- [ ] Create a cadence job that runs the consistency check on each commit
  Verification: bash scripts/config-consistency-check.sh

- [ ] Add a test case validating the check script produces expected output
  Verification: make test

- [ ] Document the new job in cadence/README.md
  Verification: grep -q "config-consistency" cadence/README.md

- [ ] Verify all new files pass syntax validation
  Verification: bash -n scripts/config-consistency-check.sh && grep -q "config-consistency" cadence/README.md
