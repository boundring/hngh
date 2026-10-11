<!-- plan: status=accepted risk=normal accepted=2026-10-11T00:35:23Z -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-10 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implement a cadence-aware job scheduling heuristic to reduce redundant automation runs on identical inputs, grounded in the research line of deterministic job deduplication.

## Steps

- [ ] Create `cadence/filter.sh` with a basic hash-check function
  Verification: bash -n cadence/filter.sh

- [ ] Create `tests/test_cadence.sh` to validate the filter logic
  Verification: bash tests/test_cadence.sh

- [ ] Update `jobs/trigger.sh` to invoke the filter before execution
  Verification: bash -n jobs/trigger.sh

- [ ] Create `dashboard/cadence.md` documenting the new cadence logic
  Verification: git grep cadence dashboard/cadence.md

- [ ] Run `make test` to confirm no regressions
  Verification: make test
