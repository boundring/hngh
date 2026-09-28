<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-28 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence job scheduler that runs periodic digest generation tasks
  Verification: bash -n cadence/scheduler.sh

- [ ] Create a test script that validates scheduler output format
  Verification: python3 tests/test_scheduler_output.py

- [ ] Add a dashboard integration script that displays cadence job status
  Verification: bash -n dashboard/cadence_status.sh

- [ ] Write a lib utility for job completion verification
  Verification: bash -n lib/job_verify.py

- [ ] Add a make test target that exercises the full cadence pipeline
  Verification: make test

- [ ] Create a digest template that the scheduler populates on each run
  Verification: bash -n jobs/digest_template.sh
