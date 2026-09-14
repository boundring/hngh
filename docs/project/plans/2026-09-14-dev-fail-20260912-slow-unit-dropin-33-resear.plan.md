<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-14 - dev-fail-20260912-slow-unit-dropin-33-resear (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the research line fail-20260910-overnight-plan-accept-blocked-2026-09-09-stall-recovery-and-operator-surfaces by adding a deterministic pre-commit linter that enforces the required Verification field on every step block, preventing parser rejections.

## Steps

- [ ] Create scripts/validate-plan-format.sh to parse plan markdown and fail if any '- [ ]' line lacks an indented 'Verification:' line
  Verification: bash -n scripts/validate-plan-format.sh
- [ ] Add tests/test-validate-plan-format.sh with fixture cases for valid plans, missing verification lines, and empty steps
  Verification: make test
- [ ] Integrate the validator into the existing make test target or add a dedicated make check-plans hook that runs before commit
  Verification: grep -q "validate-plan-format" Makefile && make test
- [ ] Update docs/research/2026-09-14-fail-20260910-overnight-plan-accept-blocked-2026-09-09-stall-recovery-and-operator-surfaces.md to record the linter as the closure mechanism
  Verification: grep -q "validate-plan-format" docs/research/2026-09-14-fail-20260910-overnight-plan-accept-blocked-2026-09-09-stall-recovery-and-operator-surfaces.md
