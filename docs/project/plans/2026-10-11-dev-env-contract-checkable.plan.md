<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-11 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a health-check script under scripts/ that validates core automation paths exist and are readable
  Verification: bash -n scripts/health-check.sh && bash scripts/health-check.sh

- [ ] Add a test for the health-check script under tests/ that asserts exit code 0 on success
  Verification: make test

- [ ] Add a cadence entry under cadence/ that runs the health-check script on a 6-hour interval
  Verification: bash -n cadence/run-health-check.sh

- [ ] Add a verification step in tests/ that confirms cadence entry is syntactically valid
  Verification: bash -n cadence/run-health-check.sh && grep -q "health-check" cadence/run-health-check.sh

- [ ] Add a README note under dashboard/ documenting the new health-check cadence
  Verification: grep -q "health-check" dashboard/README.md
