<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-10 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a shell script that validates hngh-automation job definitions before execution
  Verification: bash -n jobs/validate-job.sh

- [ ] Create a test script that exercises the new job validator against sample inputs
  Verification: bash tests/test-job-validator.sh

- [ ] Update the main Makefile to include the new validation step in the test pipeline
  Verification: grep -q 'validate-job' Makefile

- [ ] Add a README note documenting the new validation workflow
  Verification: grep -q 'job validation' jobs/README.md

- [ ] Run the full test suite to confirm no regressions
  Verification: make test
