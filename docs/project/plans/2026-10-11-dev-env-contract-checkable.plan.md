<!-- plan: status=accepted risk=normal accepted=2026-10-11T11:06:52Z -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-11 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implement the "local cadence validation" research line by introducing a syntax-check script for cadence definitions and integrating it into the existing test suite.

## Steps

- [ ] Create `scripts/cadence-validate.sh` to perform syntax checks on cadence files
  Verification: `bash -n scripts/cadence-validate.sh`
- [ ] Add `tests/cadence-validate-test.sh` to assert the script exits cleanly on valid input
  Verification: `bash tests/cadence-validate-test.sh`
- [ ] Update `lib/cadence-loader.py` to invoke the validation script before loading
  Verification: `grep -q cadence-validate lib/cadence-loader.py`
- [ ] Add `jobs/cadence-check.yml` to run the validation script as a pre-commit hook
  Verification: `make test`
- [ ] Update `dashboard/cadence-status.json` to reflect validation results
  Verification: `python3 -c "import json; json.load(open('dashboard/cadence-status.json'))"`
