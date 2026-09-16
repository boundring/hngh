<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-16 - dev-fail-20260914-Which-artifact-records-the (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line "fail-20260914-Which-artifact-records-the-plan-acceptan" by establishing a structured artifact schema that explicitly distinguishes `parse_pass` from `operator_override`, and the line "fail-20260915-Does-the-beat-script-s-state-model-disti" by defining distinct state markers for timeout-complete versus in-progress conditions within the automation scripts.

## Steps

- [ ] Create a JSON schema file at `lib/schemas/plan-acceptance.schema.json` that defines required fields for `event_type`, `parse_pass` (boolean), and `operator_override` (boolean) to enforce R2 distinction.
  Verification: python3 -c "import json; json.load(open('lib/schemas/plan-acceptance.schema.json'))"

- [ ] Add a state marker validation function to `scripts/state_model.sh` that explicitly checks for the presence of a `timeout_complete` token versus an `in_progress` timestamp, returning distinct exit codes.
  Verification: bash -n scripts/state_model.sh

- [ ] Write a shell test script at `tests/test_state_markers.sh` that asserts the validation function returns different exit codes for timeout-complete and in-progress states.
  Verification: bash tests/test_state_markers.sh

- [ ] Update `cadence/plan_acceptance.py` to emit structured acceptance records conforming to the new schema, ensuring both parse_pass and operator_override are logged separately.
  Verification: python3 -c "import ast; ast.parse(open('cadence/plan_acceptance.py').read())"

- [ ] Add a test case to `tests/test_plan_acceptance.py` that verifies the emitted record contains distinct boolean values for parse_pass and operator_override, not a single conflated flag.
  Verification: python3 -c "import ast; ast.parse(open('tests/test_plan_acceptance.py').read())"
