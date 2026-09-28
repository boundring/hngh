<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-28 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job template under jobs/ for a simple data ingestion task
  Verification: bash -n jobs/data-ingest-template.sh

- [ ] Create a verification script under scripts/ that validates job template syntax
  Verification: bash scripts/validate-job-template.sh

- [ ] Update cadence/ to include the new job template in the automation schedule
  Verification: grep -q "data-ingest" cadence/schedule.conf

- [ ] Add a test case under tests/ that exercises the new job template
  Verification: make test

- [ ] Update dashboard/ to reflect the new job template in the status view
  Verification: grep -q "data-ingest" dashboard/status.conf

- [ ] Run full test suite to confirm no regressions
  Verification: make test
