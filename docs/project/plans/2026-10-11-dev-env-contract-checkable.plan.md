<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-11 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Standardize cadence job output parsing to improve dashboard digest reliability.

## Steps

- [ ] Create `scripts/validate-job-output.sh` to check job output format
  Verification: `bash -n scripts/validate-job-output.sh`

- [ ] Add `tests/test-validate-job-output.sh` to verify the validation script
  Verification: `bash tests/test-validate-job-output.sh`

- [ ] Update `cadence/runner.sh` to invoke the validation script
  Verification: `bash -n cadence/runner.sh`

- [ ] Update `digest/parse-output.py` to handle validated output
  Verification: `python3 -c "import ast; ast.parse(open('digest/parse-output.py').read())"`

- [ ] Run `make test` to confirm no regressions
  Verification: `make test`
