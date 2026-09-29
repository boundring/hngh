<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-29 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new data-validation job script under jobs/
  Verification: bash -n jobs/data-validation.sh

- [ ] Add unit tests for the new validation job under tests/
  Verification: bash -n tests/test_data_validation.sh

- [ ] Register the new job in cadence configuration
  Verification: grep -q 'data-validation' cadence/jobs.yaml

- [ ] Run full test suite to confirm no regressions
  Verification: make test
