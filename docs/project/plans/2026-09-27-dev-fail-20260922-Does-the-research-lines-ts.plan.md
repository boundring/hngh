<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-27 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job template under jobs/ that exercises a single automation primitive with no external dependencies
  Verification: bash -n jobs/new-primitive-job.sh && make test

- [ ] Add a verification script under scripts/ that validates the new job template syntax and structure
  Verification: bash scripts/verify-new-primitive-job.sh && make test

- [ ] Add a unit test under tests/ that asserts the new job template passes all structural checks
  Verification: make test

- [ ] Add a cadence entry under cadence/ that schedules the new job with a safe default interval
  Verification: bash -n cadence/new-primitive-job.cron && make test

- [ ] Add a dashboard snippet under dashboard/ that exposes the new job's status for monitoring
  Verification: bash -n dashboard/new-primitive-job-status.md && make test

- [ ] Add a digest entry under digest/ that summarizes the new job's output for periodic review
  Verification: bash -n digest/new-primitive-job-digest.md && make test
