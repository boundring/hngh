<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-29 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence helper that validates job dependency graphs before scheduling
  Verification: bash -n cadence/validate_deps.sh

- [ ] Create a test script that asserts all jobs/ entries have required fields populated
  Verification: python3 tests/check_job_fields.py

- [ ] Add a dashboard script that lists jobs with missing verification steps
  Verification: bash dashboard/missing_verifications.sh

- [ ] Extend lib/ with a utility to parse and normalize job metadata from YAML
  Verification: node --check lib/parse_job_yaml.js

- [ ] Add a script that runs make test after each cadence validation change
  Verification: make test

- [ ] Create a digest entry template for tracking automation research progress
  Verification: bash -n digest/progress_template.sh
