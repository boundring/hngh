<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-10 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the "cadence-validation" research line by introducing a local script that asserts job output structure without touching kernel state or external credentials.

## Steps

- [ ] Create `scripts/cadence_check.sh` containing a bash function that validates a standard log line format
  Verification: bash -n scripts/cadence_check.sh

- [ ] Create `tests/test_cadence_check.sh` that invokes the script against a hardcoded sample input and asserts exit code 0
  Verification: bash -n tests/test_cadence_check.sh

- [ ] Run `make test` to ensure the new files do not break the existing pipeline
  Verification: make test

- [ ] Verify `scripts/cadence_check.sh` contains the expected function name via grep
  Verification: git grep -l check_cadence scripts/cadence_check.sh
