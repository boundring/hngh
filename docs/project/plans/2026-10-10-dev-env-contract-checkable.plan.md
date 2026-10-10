<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-10 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a repository health check script under scripts/ that validates core automation paths exist and are readable
  Verification: bash scripts/repo-health-check.sh

- [ ] Create a cadence job that runs the health check script on a daily schedule and logs results to dashboard/
  Verification: bash -n cadence/daily-health-job.sh

- [ ] Add a test for the health check script under tests/ to ensure it exits cleanly on a valid repository state
  Verification: make test

- [ ] Update the dashboard digest to include health check status in its next run output
  Verification: bash -n dashboard/digest-template.sh

- [ ] Verify all new scripts pass syntax validation before integration
  Verification: bash -n scripts/repo-health-check.sh && bash -n cadence/daily-health-job.sh && bash -n dashboard/digest-template.sh
