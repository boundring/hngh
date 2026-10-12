<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-12 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Rationale: Implements the research line on "automation verification hygiene" by introducing a dry-run validation script to gate cadence job execution without side effects.

## Steps

- [ ] Create `scripts/dry-run.sh` that validates job definition syntax via `bash -n`.
  Verification: `bash -n scripts/dry-run.sh`
- [ ] Create `tests/test_dry_run.sh` that asserts the script exits zero on valid input.
  Verification: `bash -n tests/test_dry_run.sh`
- [ ] Update `cadence/monitor.yaml` to reference the new dry-run script path.
  Verification: `grep -q dry-run cadence/monitor.yaml`
- [ ] Ensure `make test` passes with the new test suite.
  Verification: `make test`
