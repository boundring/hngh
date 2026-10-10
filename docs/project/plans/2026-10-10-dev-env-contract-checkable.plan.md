<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-10 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a health-check script under scripts/ that validates repository structure
  Verification: bash scripts/health-check.sh

- [ ] Add a corresponding test case under tests/ that exercises the health check
  Verification: make test

- [ ] Update cadence/README with the new verification step documentation
  Verification: grep -q "health-check" cadence/README
