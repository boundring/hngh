<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-10 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new test script under tests/
  Verification: bash -n tests/test_new_job.sh

- [ ] Add a corresponding job script under jobs/
  Verification: bash -n jobs/new_job.sh

- [ ] Add a cadence entry under cadence/
  Verification: grep -q 'new_job' cadence/schedule.conf

- [ ] Run make test to verify integration
  Verification: make test
