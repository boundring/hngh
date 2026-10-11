<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-11 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence runner script that iterates over job definitions in jobs/ and executes them sequentially
  Verification: bash -n cadence/run_jobs.sh

- [ ] Create a test harness in tests/ that validates each job script returns exit code 0 on success
  Verification: bash tests/test_job_runner.sh

- [ ] Add a dashboard digest entry that records job completion timestamps to digest/
  Verification: grep -q "job_timestamp" digest/last_run.log

- [ ] Extend lib/ to expose a job status query function callable by the cadence runner
  Verification: bash -n lib/job_status.py

- [ ] Add a cleanup step that prunes digest entries older than 7 days without deleting source jobs
  Verification: bash scripts/prune_digest.sh

- [ ] Wire the cadence runner into the existing make test pipeline as a pre-check target
  Verification: make test
