<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-20 - dev-fail-20260918-Does-the-path-collision-bu (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line for standardizing job execution telemetry by adding a lightweight logging wrapper to the existing automation shell scripts and validating its integration with the current test suite.

## Steps

- [ ] Create `lib/telemetry.sh` containing a `log_event` function that appends timestamped JSON lines to `[redacted path]
  Verification: bash -n lib/telemetry.sh

- [ ] Add a unit test in `tests/test_telemetry.sh` that sources the library and asserts a log entry is created after calling `log_event`.
  Verification: bash tests/test_telemetry.sh

- [ ] Modify `jobs/run_pipeline.sh` to source `lib/telemetry.sh` and call `log_event` before executing the main pipeline logic.
  Verification: make test

- [ ] Add a regression check in `tests/test_integration.sh` that verifies the telemetry log file exists after a simulated pipeline run.
  Verification: make test
