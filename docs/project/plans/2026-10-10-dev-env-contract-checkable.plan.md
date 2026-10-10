<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-10 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The research line "hngh-automation: cadence-scheduler" is implemented by adding a deterministic job-ordering script that sorts pending tasks by priority and timestamp before dispatch.

## Steps

- [ ] Create a priority-sorting script under `jobs/` that reads a pending-task list and outputs them ordered by priority then timestamp
  Verification: bash -n jobs/sort-pending.sh && bash jobs/sort-pending.sh --help
- [ ] Add a verification test under `tests/` that asserts the sort script produces stable output for a fixed input set
  Verification: bash tests/test-sort-pending.sh
- [ ] Integrate the sort script into the existing `make test` pipeline so it runs before dispatch logic
  Verification: make test
- [ ] Create a dry-run wrapper under `scripts/` that invokes the sort script and logs the resulting order without executing jobs
  Verification: bash -n scripts/dry-run-sort.sh && bash scripts/dry-run-sort.sh --verify
- [ ] Add a cadence configuration snippet under `cadence/` that defines default priority levels for standard job categories
  Verification: grep -q "priority_levels" cadence/default-config.yaml
- [ ] Write a regression test under `tests/` that confirms the dry-run wrapper output matches the sort script output for identical inputs
  Verification: bash tests/test-dry-run-consistency.sh
