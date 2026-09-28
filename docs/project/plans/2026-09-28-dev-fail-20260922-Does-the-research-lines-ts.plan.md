<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-28 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `lib/hngh-automation/utils.py` module with a `validate_input` function that checks required fields in a config dict
  Verification: python3 -c "import sys; sys.path.insert(0, '.'); from lib.hngh-automation.utils import validate_input; print(validate_input({'name': 'test'}))"

- [ ] Create `jobs/validate-config.sh` script that runs `make test` and exits 0 on success
  Verification: bash -n jobs/validate-config.sh

- [ ] Add `tests/test_validate_input.py` with a single test case asserting the function returns True for valid input
  Verification: python3 tests/test_validate_input.py

- [ ] Update `cadence/run.sh` to call `validate-config.sh` before proceeding with job execution
  Verification: bash -n cadence/run.sh

- [ ] Commit all changes and run `make test` to confirm the pipeline passes
  Verification: make test
