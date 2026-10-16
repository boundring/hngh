<!-- plan: status=accepted risk=normal accepted=2026-10-16T05:06:16Z -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-16 - dev-fail-20260917-overnight-plan-accept-bloc (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new cadence job that runs a health-check script on a daily schedule
  Verification: `bash -n cadence/health-check-job.sh`

- [ ] Create a verification script that confirms the cadence job file is syntactically valid
  Verification: `bash cadence/health-check-job.sh --dry-run`

- [ ] Add a test case that validates the new cadence job integrates with existing automation
  Verification: `make test`

- [ ] Update the dashboard digest to include the new health-check job status
  Verification: `bash -n dashboard/digest-template.sh`

- [ ] Run the full test suite to confirm no regressions from the new cadence job
  Verification: `make test`
