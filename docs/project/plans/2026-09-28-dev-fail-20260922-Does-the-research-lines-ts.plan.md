<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-28 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence validation script that checks job file syntax and structure
  Verification: bash -n cadence/validate.sh

- [ ] Create a test case that exercises the new validation script against sample job files
  Verification: bash cadence/validate.sh tests/sample-job.yaml

- [ ] Add a git hook to enforce validation before commits in the cadence directory
  Verification: git grep -l "validate.sh" cadence/

- [ ] Update the dashboard README to document the new validation workflow
  Verification: grep -c "validation" dashboard/README.md

- [ ] Run make test to confirm all existing tests still pass after changes
  Verification: make test
