<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-17 - dev-fail-20260916-What-is-the-exact-systemd- (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line on deterministic job scheduling by introducing a new bash-based scheduler script and its corresponding unit test suite to ensure reliable task execution without external dependencies.

## Steps

- [ ] Create scripts/scheduler.sh implementing a basic loop that reads job definitions from jobs/ and executes them sequentially with error handling.
  Verification: bash -n scripts/scheduler.sh

- [ ] Add tests/test_scheduler.sh containing assertions that verify the scheduler correctly parses job files and handles missing dependencies.
  Verification: make test

- [ ] Define a sample job configuration in jobs/sample_job.json to provide input data for the scheduler's parsing logic.
  Verification: grep -q "name" jobs/sample_job.json

- [ ] Update lib/utils.sh to include helper functions for logging and timestamping that are sourced by the new scheduler script.
  Verification: bash -n lib/utils.sh
