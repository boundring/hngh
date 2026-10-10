<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-10 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the "Pre-execution script linting" research line by adding a syntax-check gate to the job submission workflow.

## Steps

- [ ] Create scripts/lint-job.sh to validate bash syntax on new job scripts
  Verification: bash -n scripts/lint-job.sh

- [ ] Create tests/test-lint.sh to verify the lint script runs without errors
  Verification: bash tests/test-lint.sh

- [ ] Update jobs/run.sh to invoke the lint script before execution
  Verification: grep -q 'lint-job' jobs/run.sh

- [ ] Update cadence/ directory to register the new lint step
  Verification: git grep -q 'lint-job' cadence/
