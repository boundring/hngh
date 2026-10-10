<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-10 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Rationale: Implements the hngh-automation research line on cadence-job status reporting to surface job health metrics without modifying execution paths.

## Steps

- [ ] Create `scripts/cadence-status-check.sh` that iterates `jobs/` and prints active status markers
  Verification: `bash -n scripts/cadence-status-check.sh`
- [ ] Create `tests/test_cadence_status.sh` that asserts the script exits 0 on a populated `jobs/` directory
  Verification: `bash -n tests/test_cadence_status.sh`
- [ ] Confirm the new scripts integrate cleanly with the existing build pipeline
  Verification: `make test`
