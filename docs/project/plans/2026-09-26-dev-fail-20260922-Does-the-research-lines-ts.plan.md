<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Rationale: Implements the "configuration validation" research line by adding a new automation job that checks pipeline configuration consistency before execution.

## Steps

- [ ] Create a configuration linting script at scripts/lint-config.sh that validates YAML syntax
  Verification: bash -n scripts/lint-config.sh

- [ ] Add a test case at tests/test-lint-config.sh that exercises the linting script
  Verification: bash tests/test-lint-config.sh

- [ ] Update the test runner at cadence/run-tests.sh to include the new linting check
  Verification: bash -n cadence/run-tests.sh

- [ ] Create a helper function at lib/config-utils.sh for configuration parsing
  Verification: bash -n lib/config-utils.sh

- [ ] Add a dashboard report at dashboard/config-health.md documenting the validation coverage
  Verification: git grep -c "config-health" dashboard/config-health.md
