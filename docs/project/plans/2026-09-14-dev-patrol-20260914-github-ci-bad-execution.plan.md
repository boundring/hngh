<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-14 - dev-patrol-20260914-github-ci-bad-execution (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the patrol-20260914-github-ci-bad-execution research line by adding a guardrail check that detects two consecutive bad-execution outcomes and demotes the line, ensuring the intended closure mechanism is explicitly tested.

## Steps

- [ ] Create `lib/patrol_guardrails.py` implementing a function `check_consecutive_bad_executions(outcomes: list[str]) -> bool` that returns True if the last two entries are both "bad-execution".
  Verification: python3 -c "import sys; sys.path.insert(0, 'lib'); from patrol_guardrails import check_consecutive_bad_executions; assert check_consecutive_bad_executions(['ok', 'bad-execution', 'bad-execution']) == True"

- [ ] Create `tests/test_patrol_guardrails.py` with a test case that asserts `check_consecutive_bad_executions` returns False for non-consecutive failures and True for two consecutive "bad-execution" entries.
  Verification: make test

- [ ] Add a CLI entry point in `scripts/patrol_check.py` that reads a JSON file of recent outcomes from stdin and exits with code 1 if the guardrail fires, printing "DEMOTE: two consecutive bad-executions".
  Verification: bash -n scripts/patrol_check.py

- [ ] Create `tests/test_patrol_check_cli.py` that pipes a sample JSON array containing two trailing "bad-execution" entries into `scripts/patrol_check.py` and asserts the exit code is 1 and stdout contains "DEMOTE".
  Verification: make test

- [ ] Update `cadence/patrol-cadence.yml` to include a step that invokes `python3 scripts/patrol_check.py < digest/outcomes.json` before scoring, ensuring the guardrail runs in the standard cadence.
  Verification: grep -q "patrol_check.py" cadence/patrol-cadence.yml
