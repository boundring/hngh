<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-28 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `scripts/hngh-status-report.sh` that outputs current job counts from `jobs/` directory
  Verification: bash -n scripts/hngh-status-report.sh

- [ ] Create `tests/test-status-report.sh` that asserts the script exits 0 and prints job count
  Verification: bash tests/test-status-report.sh

- [ ] Add a cadence job `cadence/run-status-report.cron` that invokes the script every 6 hours
  Verification: grep -q "run-status-report" cadence/run-status-report.cron

- [ ] Update `dashboard/README.md` to document the new status report endpoint
  Verification: grep -q "status-report" dashboard/README.md

- [ ] Run `make test` to confirm all existing tests still pass after additions
  Verification: make test
