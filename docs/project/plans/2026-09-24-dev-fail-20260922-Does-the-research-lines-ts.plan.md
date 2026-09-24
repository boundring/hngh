<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-24 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Rationale: Implements the output-verification research line by adding a script that validates job output format before dashboard ingestion, ensuring consistent data flow.

## Steps

- [ ] Add a validation script that checks job output format compliance
  Verification: bash -n scripts/validate-output.sh

- [ ] Create a test that exercises the validation script against sample output
  Verification: make test

- [ ] Add a cadence job that runs the validation script before dashboard update
  Verification: bash -n cadence/run-validation.sh

- [ ] Verify the new cadence job integrates with existing test suite
  Verification: make test
