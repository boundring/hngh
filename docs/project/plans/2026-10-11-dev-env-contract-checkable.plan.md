<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-11 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a test helper script that validates test output format compliance
  Verification: bash -n jobs/test-helpers/format-check.sh

- [ ] Create a cadence script that runs format-check.sh and reports pass/fail status
  Verification: bash cadence/run-format-check.sh

- [ ] Update Makefile to include format-check.sh in the test target
  Verification: grep -q "format-check" Makefile

- [ ] Add a dashboard snippet that displays format-check results
  Verification: grep -q "format-check" dashboard/format-status.md

- [ ] Verify all new scripts pass syntax validation
  Verification: bash -n jobs/test-helpers/format-check.sh && bash -n cadence/run-format-check.sh
