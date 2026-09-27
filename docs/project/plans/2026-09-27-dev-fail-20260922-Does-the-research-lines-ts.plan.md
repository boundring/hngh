<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-27 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a job template for automated test runs in jobs/
  Verification: bash -n jobs/test-template.sh

- [ ] Create a cadence script that triggers test runs on schedule
  Verification: bash -n cadence/run-cadence.sh

- [ ] Add a verification script for dashboard health checks
  Verification: python3 dashboard/health-check.py

- [ ] Create a digest script that summarizes test results
  Verification: bash -n scripts/digest-results.sh
