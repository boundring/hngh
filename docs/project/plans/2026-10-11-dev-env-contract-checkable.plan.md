<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-11 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence helper script that validates a sample job manifest structure
  Verification: bash -n cadence/validate-job.sh

- [ ] Add unit test for cadence helper that asserts valid manifest passes and invalid manifest fails
  Verification: make test

- [ ] Add a digest helper script that summarizes a single job's status from a sample log
  Verification: bash -n digest/summarize-job.sh

- [ ] Add unit test for digest helper that asserts correct summary output for a known log
  Verification: make test

- [ ] Add a lib utility that parses a job manifest and returns its name field
  Verification: bash -n lib/parse-manifest.py

- [ ] Add unit test for lib utility that asserts correct name extraction from a known manifest
  Verification: make test
