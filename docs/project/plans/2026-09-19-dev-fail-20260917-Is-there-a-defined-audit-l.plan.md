<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-19 - dev-fail-20260917-Is-there-a-defined-audit-l (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line for automating job lifecycle tracking by introducing a stateless status parser and a local test harness to validate log ingestion without external dependencies.

## Steps

- [ ] Create `lib/status_parser.py` implementing a pure function that maps raw log strings to standardized job states (pending, running, success, failure).
  Verification: python3 -c "import sys; sys.path.insert(0, 'lib'); from status_parser import parse_status; assert parse_status('BUILD SUCCESS') == 'success'"

- [ ] Add `tests/test_status_parser.py` containing three assertions that verify the parser correctly handles edge cases like empty strings and malformed log lines.
  Verification: make test

- [ ] Create `scripts/ingest_logs.sh` to read a local fixture file and invoke the Python parser, writing results to a temporary JSON structure using only stdlib modules.
  Verification: bash -n scripts/ingest_logs.sh

- [ ] Add `tests/fixtures/sample_log.txt` containing five lines of simulated CI output covering all four state transitions for manual verification.
  Verification: grep -q "BUILD SUCCESS" tests/fixtures/sample_log.txt

- [ ] Update `Makefile` to include a new target `test-parser` that executes the Python test suite and ensures it exits with code zero before proceeding.
  Verification: make test
