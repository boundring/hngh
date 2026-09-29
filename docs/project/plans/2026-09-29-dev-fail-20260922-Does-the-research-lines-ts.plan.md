<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-29 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Rationale: Implements the cadence-scheduling research line by adding a lightweight job runner that validates and executes scheduled automation tasks.

## Steps

- [ ] Add a cadence-validation script that checks job definition syntax
  Verification: bash -n scripts/cadence-validate.sh

- [ ] Add unit tests for cadence validation logic
  Verification: make test

- [ ] Add a digest-summary script that aggregates job results
  Verification: bash -n scripts/digest-summary.sh

- [ ] Add tests for digest summary generation
  Verification: make test

- [ ] Update the automation test suite to include new validations
  Verification: make test

- [ ] Verify all new scripts pass syntax checks
  Verification: bash -n scripts/cadence-validate.sh && bash -n scripts/digest-summary.sh
