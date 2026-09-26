<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a script that validates cadence job completion markers in the jobs directory
  Verification: bash -n scripts/cadence-check.sh

- [ ] Add a test that validates the cadence check script runs without errors
  Verification: make test

- [ ] Add a script that logs cadence state transitions to the cadence directory
  Verification: bash -n scripts/cadence-log.sh

- [ ] Add a test that validates the log script produces output
  Verification: bash scripts/cadence-log.sh

- [ ] Add a verification script for dashboard state consistency in the dashboard directory
  Verification: bash -n scripts/dashboard-verify.sh

- [ ] Add a test that validates dashboard verification
  Verification: make test
