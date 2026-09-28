<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-28 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence job that validates lib/ structure on every commit
  Verification: make test
- [ ] Create a scripts/validate-commit.sh that checks no forbidden paths are modified
  Verification: bash -n scripts/validate-commit.sh
- [ ] Add a cadence/commit-gate.sh script that runs make test before allowing merge
  Verification: bash scripts/commit-gate.sh
- [ ] Update lib/README.md with the new cadence validation workflow
  Verification: grep -q "cadence validation" lib/README.md
- [ ] Add a tests/validate-plan.sh script that confirms all steps are present
  Verification: bash tests/validate-plan.sh
