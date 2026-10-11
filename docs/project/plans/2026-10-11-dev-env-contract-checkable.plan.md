<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-11 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implement a digest-driven cadence scheduler to advance the hngh-automation research line toward autonomous job execution.

## Steps

- [ ] Create `scripts/validate_digest.py` to check digest schema compliance
  Verification: python3 scripts/validate_digest.py --dry-run

- [ ] Create `jobs/run_digest_check.sh` to invoke the validator script
  Verification: bash -n jobs/run_digest_check.sh

- [ ] Create `tests/test_digest_check.sh` to assert validator output
  Verification: bash tests/test_digest_check.sh

- [ ] Create `cadence/schedule_digest.sh` to orchestrate the job lifecycle
  Verification: bash -n cadence/schedule_digest.sh

- [ ] Create `scripts/run_pipeline.sh` to wrap the test suite
  Verification: bash -n scripts/run_pipeline.sh
