<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-14 - dev-fail-20260912-slow-unit-dropin-33-resear (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the research line fail-20260910-overnight-plan-accept-blocked-2026-09-09-stall-recovery-and-operator-surfaces by adding a pre-commit linter to hngh-automation that validates step blocks for mandatory Verification fields, preventing deterministic parser rejections.

## Steps

- [ ] Create scripts/validate-plan-format.py implementing a regex check that scans plan markdown files for step blocks and asserts each contains an indented 'Verification:' line
  Verification: python3 scripts/validate-plan-format.py --help exits with code 0 and prints usage text
- [ ] Add tests/test_validate_plan_format.py containing two fixture strings (one valid, one missing Verification) and assert the validator passes/fails correctly
  Verification: make test runs green in hngh-automation
- [ ] Wire the validator into the existing make test target by appending a python3 invocation to scripts/run-tests.sh or equivalent harness script
  Verification: grep -q "validate-plan-format" scripts/run-tests.sh
- [ ] Add a regression fixture tests/fixtures/plan-missing-verification.md with a step block lacking the Verification line for negative testing
  Verification: bash -n scripts/run-tests.sh exits with code 0
- [ ] Update cadence/README.md to document that plan documents must pass scripts/validate-plan-format.py before submission
  Verification: grep -q "validate-plan-format" cadence/README.md
