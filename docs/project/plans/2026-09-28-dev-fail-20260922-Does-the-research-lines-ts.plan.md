<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-28 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new data-processing job template under jobs/ with a valid bash syntax check
  Verification: bash -n jobs/data-processing.sh

- [ ] Create a verification script that confirms the job template is structurally complete
  Verification: bash scripts/verify-job-template.sh

- [ ] Add unit tests for the new job template under tests/
  Verification: make test

- [ ] Update cadence/ to register the new job template in the scheduling manifest
  Verification: grep -q "data-processing" cadence/schedule.yaml

- [ ] Add a digest entry documenting the new job template
  Verification: grep -q "data-processing" digest/README.md

- [ ] Run full test suite to confirm no regressions from the new job template
  Verification: make test
