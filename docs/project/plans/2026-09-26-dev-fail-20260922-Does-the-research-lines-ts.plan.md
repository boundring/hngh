<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job script under jobs/
  Verification: bash -n jobs/new_job.sh && make test

- [ ] Add a test for the new job
  Verification: make test

- [ ] Add cadence tracking for the new job
  Verification: bash scripts/cadence_check.sh && make test
