<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-14 - dev-fail-20260910-overnight-plan-accept-bloc (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the fail-20260910-overnight-plan-accept-blocked-2026-09-09-stall-recovery-and-operator-surfaces research line by adding a deterministic parser check that enforces the presence of a Verification line for every step in hngh-automation plan documents, preventing the "step 1 has no Verification line" auto-accept failure from recurring.

## Steps

- [ ] Create `scripts/validate-plan-format.sh` that iterates over plan files and asserts each `- [ ]` step is followed by an indented `Verification:` line
  Verification: bash -n scripts/validate-plan-format.sh
- [ ] Add a test fixture in `tests/fixtures/plan-missing-verification.md` containing a step without a Verification line to serve as a negative case
  Verification: grep -q "Verification:" tests/fixtures/plan-missing-verification.md && exit 1 || true
- [ ] Extend the existing test suite in `tests/test-plan-validation.sh` to invoke `scripts/validate-plan-format.sh` against both valid and invalid fixtures, asserting correct pass/fail behavior
  Verification: bash tests/test-plan-validation.sh
- [ ] Run the full repository test suite to confirm the new validation logic integrates cleanly without breaking existing gates
  Verification: make test
