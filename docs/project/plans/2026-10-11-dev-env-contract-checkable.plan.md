<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-11 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `lib/hngh-automation/utils.sh` helper that validates input paths before processing
  Verification: bash -n lib/hngh-automation/utils.sh

- [ ] Add a `tests/test_utils.sh` script that exercises path validation with valid and invalid inputs
  Verification: bash tests/test_utils.sh

- [ ] Update `jobs/run.sh` to call the new path validation helper before executing job payloads
  Verification: bash -n jobs/run.sh

- [ ] Add a `scripts/validate-input.sh` entrypoint that demonstrates the helper in isolation
  Verification: bash scripts/validate-input.sh

- [ ] Add `cadence/validate-input.md` documenting the new validation contract for future contributors
  Verification: grep -q "validate-input" cadence/validate-input.md

- [ ] Run full test suite to confirm no regressions after adding the validation layer
  Verification: make test
