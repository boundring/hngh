<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-12 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implementing the cadence output normalization research line by introducing a standardized formatting script and corresponding unit tests.

## Steps

- [ ] Create a shell script to normalize cadence job output logs
  Verification: bash -n scripts/cadence_format.sh
- [ ] Add a unit test script to validate the formatting logic
  Verification: bash -n tests/cadence_format_test.sh
- [ ] Wire the formatting script into the cadence job definition
  Verification: grep -q cadence_format cadence/format_job.sh
- [ ] Run the full test suite to confirm no regressions
  Verification: make test
