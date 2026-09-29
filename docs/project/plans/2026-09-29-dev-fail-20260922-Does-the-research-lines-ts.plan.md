<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-29 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale

This plan implements the **hngh-automation test-utility research line** by adding a lightweight validation script that checks job definition syntax before execution, reducing runtime failures from malformed inputs.

## Steps

- [ ] Create a shell script under `scripts/` that validates job definition files for required fields and correct syntax
  Verification: `bash -n scripts/validate-job-def.sh`

- [ ] Add a test case under `tests/` that exercises the validation script with a sample malformed job definition
  Verification: `bash tests/test-validate-job-def.sh`

- [ ] Update `make test` to include the new validation script check in the test suite
  Verification: `make test`

- [ ] Create a helper script under `cadence/` that wraps the validation for use in automated job pipelines
  Verification: `bash -n cadence/run-with-validation.sh`

- [ ] Add documentation under `dashboard/` describing the validation script usage and expected output format
  Verification: `grep -l "validation" dashboard/*.md`

- [ ] Verify all new scripts pass syntax checks and the full test suite remains green
  Verification: `make test && bash -n scripts/validate-job-def.sh && bash -n cadence/run-with-validation.sh`
