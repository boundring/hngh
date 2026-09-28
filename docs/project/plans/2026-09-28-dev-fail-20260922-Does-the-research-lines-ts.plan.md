<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-28 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job template for batch data ingestion under jobs/ with a basic structure and placeholder logic
  Verification: bash -n jobs/batch-ingest.sh

- [ ] Create a verification script that runs the new job template and confirms it exits cleanly
  Verification: bash jobs/batch-ingest.sh

- [ ] Add a test case in tests/ that validates the job template produces expected output format
  Verification: make test

- [ ] Update cadence/ to register the new job template for periodic execution
  Verification: grep -q batch-ingest cadence/schedule.yaml

- [ ] Add a dashboard snippet that displays the new job's status and last run timestamp
  Verification: bash -n dashboard/job-status.sh

- [ ] Run the full test suite to confirm no regressions from the new job template addition
  Verification: make test
