<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-27 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a state-validation script under scripts/ that checks automation readiness
  Verification: bash -n scripts/state-check.sh

- [ ] Wire the state-check script into cadence/ as a runnable job
  Verification: bash -n cadence/state-check-job.sh

- [ ] Add a test for the state-check script under tests/
  Verification: make test

- [ ] Verify the new script passes syntax and integration checks
  Verification: bash scripts/state-check.sh && make test
