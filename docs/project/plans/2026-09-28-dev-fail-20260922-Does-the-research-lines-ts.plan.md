<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-28 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `scripts/hngh-status-check.sh` helper that outputs current cadence state
  Verification: bash -n scripts/hngh-status-check.sh

- [ ] Create `tests/test_status_check.sh` to validate the helper script runs cleanly
  Verification: bash tests/test_status_check.sh

- [ ] Add `cadence/state-summary.md` documenting expected cadence states
  Verification: grep -q "cadence" cadence/state-summary.md

- [ ] Update `jobs/run-cadence.sh` to invoke the new status-check helper before execution
  Verification: bash -n jobs/run-cadence.sh

- [ ] Add `dashboard/cadence-trace.log` template for tracking cadence execution
  Verification: grep -q "cadence" dashboard/cadence-trace.log

- [ ] Run full test suite to confirm no regressions
  Verification: make test
