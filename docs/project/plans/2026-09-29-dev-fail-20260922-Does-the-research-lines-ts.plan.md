<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-29 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new cadence job that validates automation output consistency
  Verification: bash -n cadence/validate-outputs.sh

- [ ] Create a helper script to parse automation commit logs
  Verification: python3 scripts/parse-commit-logs.py

- [ ] Add a test case for cadence job scheduling
  Verification: make test

- [ ] Update dashboard to display cadence job status
  Verification: bash -n dashboard/cadence-status.sh

- [ ] Add a digest summary for automation run results
  Verification: bash -n digest/automation-summary.sh

- [ ] Verify all new scripts pass syntax checks
  Verification: bash -n jobs/cadence/validate-outputs.sh && bash -n scripts/parse-commit-logs.py && bash -n dashboard/cadence-status.sh && bash -n digest/automation-summary.sh
