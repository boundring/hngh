<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-24 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job template for batch data processing under jobs/
  Verification: bash -n jobs/batch-data-template.sh && make test

- [ ] Create a verification script to validate job template syntax
  Verification: python3 scripts/validate-job-template.py

- [ ] Add unit tests for the new job template logic
  Verification: make test

- [ ] Update cadence configuration to register the new job template
  Verification: grep -q batch-data cadence/config.yaml && make test

- [ ] Add a dashboard snippet to display batch job status
  Verification: bash -n dashboard/batch-status-snippet.sh && make test

- [ ] Create a digest rule to summarize batch job outcomes
  Verification: python3 digest/batch-summary.py && make test
