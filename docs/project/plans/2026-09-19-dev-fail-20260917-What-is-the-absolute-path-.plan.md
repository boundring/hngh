<!-- plan: status=accepted risk=normal accepted=2026-09-20T00:04:01Z -->
# 2026-09-19 - dev-fail-20260917-What-is-the-absolute-path- (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line for standardizing job execution telemetry by introducing a lightweight, stdlib-only Python logging utility and integrating it into the existing cadence workflow to ensure consistent audit trails without altering core kernel or security boundaries.

## Steps

- [ ] Create `lib/telemetry.py` implementing a `LogEntry` dataclass and a `write_log` function that appends JSON lines to a file using only Python standard library modules.
  Verification: python3 -c "import sys; sys.path.insert(0, 'lib'); from telemetry import LogEntry, write_log; print('ok')"

- [ ] Add a unit test in `tests/test_telemetry.py` that verifies `write_log` correctly appends valid JSON lines to a temporary file and handles serialization errors gracefully.
  Verification: make test

- [ ] Update `cadence/run_job.sh` to source the telemetry module path and invoke a Python one-liner that logs job start events using the new `lib/telemetry.py`.
  Verification: bash -n cadence/run_job.sh

- [ ] Modify `scripts/digest.py` to import and use the `LogEntry` class from `lib/telemetry.py` for structuring digest output records.
  Verification: python3 scripts/digest.py --help

- [ ] Add a regression test in `tests/test_digest_integration.py` that mocks a job execution and asserts that telemetry logs are generated in the expected directory structure.
  Verification: make test
