<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-25 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a simple test utility script under scripts/ that validates basic repository state
  Verification: bash -n scripts/hngh-verify-state.sh

- [ ] Create a cadence job that runs the verification script on each commit
  Verification: make test

- [ ] Add a grep check to confirm no forbidden paths are modified
  Verification: git grep -n 'systemd\|provider\|credential' -- jobs/ scripts/ cadence/ lib/ tests/ dashboard/ digest/ | head -5

- [ ] Write a python3 stdlib script under scripts/ that checks for non-prune deletions
  Verification: python3 scripts/check-deletions.py

- [ ] Commit the new scripts and verify all tests pass
  Verification: make test
