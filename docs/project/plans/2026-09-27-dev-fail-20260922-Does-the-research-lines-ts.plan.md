<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-27 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job template for automated report generation
  Verification: bash -n jobs/report-gen/template.sh

- [ ] Create a verification script for job completion status
  Verification: python3 scripts/verify_job_status.py

- [ ] Update cadence configuration to include new job
  Verification: bash -c "grep -q 'report-gen' cadence/jobs.yaml"

- [ ] Add integration test for report generation pipeline
  Verification: make test

- [ ] Document new job in dashboard configuration
  Verification: bash -c "grep -q 'report-gen' dashboard/jobs.json"

- [ ] Verify all new scripts pass syntax checks
  Verification: bash -n jobs/report-gen/template.sh && python3 scripts/verify_job_status.py
