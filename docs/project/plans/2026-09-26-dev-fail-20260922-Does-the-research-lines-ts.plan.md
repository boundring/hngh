<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence job that validates lib/hngh-automation/schemas/ on every commit
  Verification: make test

- [ ] Create a scripts/validate-cadence.sh that runs cadence job outputs through bash -n syntax checks
  Verification: bash -n scripts/validate-cadence.sh

- [ ] Add a tests/ directory with a smoke test that confirms cadence job structure is parseable
  Verification: make test

- [ ] Add a dashboard/summary.md documenting the cadence validation pipeline
  Verification: git grep -l "cadence" dashboard/summary.md

- [ ] Add a digest/entry.md recording the research line adoption with date and scope
  Verification: git grep -l "hngh-automation" digest/entry.md

- [ ] Verify all new files pass bash -n and make test without errors
  Verification: make test
