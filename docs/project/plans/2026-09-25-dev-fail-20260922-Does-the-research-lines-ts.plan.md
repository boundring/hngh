<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-25 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a job-state reporter script that parses test output and emits completion metrics
  Verification: bash scripts/report-job-state.sh

- [ ] Add a cadence-orchestration test that validates the reporter against sample output
  Verification: make test

- [ ] Add a dashboard integration that consumes the reporter metrics
  Verification: bash -n dashboard/consume-metrics.sh

- [ ] Add a digest summary that aggregates reporter output across runs
  Verification: python3 digest/aggregate.py

- [ ] Add a lib helper for parsing job output into structured state
  Verification: bash -n lib/job-state-parser.sh

- [ ] Add a tests fixture for job-state reporter validation
  Verification: make test
