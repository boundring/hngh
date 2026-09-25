<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-25 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `jobs/status-report.sh` script that lists active jobs from the repository's job registry
  Verification: bash -n jobs/status-report.sh

- [ ] Create `tests/test-status-report.sh` to validate the script outputs expected job entries
  Verification: bash tests/test-status-report.sh

- [ ] Add `cadence/schedule-check.sh` to verify scheduled cadence entries are non-empty
  Verification: bash cadence/schedule-check.sh

- [ ] Update `dashboard/README.md` with documentation for the new status-report utility
  Verification: grep -q "status-report" dashboard/README.md

- [ ] Run `make test` to confirm all existing tests still pass after additions
  Verification: make test
