<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-16 - dev-fail-20260917-overnight-plan-accept-bloc (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a script to validate automation job definitions before execution
  Verification: bash -n jobs/validate-job-def.sh

- [ ] Create a helper script that checks cadence schedule consistency
  Verification: python3 cadence/check-schedule.py

- [ ] Add a test script that validates automation output format compliance
  Verification: make test

- [ ] Create a script to verify dashboard digest file structure
  Verification: bash scripts/verify-digest-structure.sh

- [ ] Add a linting step to enforce naming conventions for automation jobs
  Verification: bash -n jobs/lint-job-names.sh

- [ ] Create a verification script that confirms all automation paths are under allowed directories
  Verification: python3 scripts/check-path-constraints.py
