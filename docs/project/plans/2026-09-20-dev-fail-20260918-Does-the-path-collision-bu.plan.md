<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-20 - dev-fail-20260918-Does-the-path-collision-bu (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the research line for standardizing job execution telemetry by adding a lightweight logging wrapper to the existing automation framework.

## Steps

- [ ] Create `lib/telemetry.sh` containing a `log_event` function that appends timestamped JSON lines to `[redacted path]
  Verification: bash -n lib/telemetry.sh
- [ ] Add a test case in `tests/test_telemetry.sh` that sources the library and asserts the log file is created with valid structure.
  Verification: make test
- [ ] Update `jobs/run_pipeline.sh` to source `lib/telemetry.sh` and call `log_event` at start and end of execution.
  Verification: bash -n jobs/run_pipeline.sh
- [ ] Add a grep check in `tests/test_telemetry.sh` to verify that `run_pipeline.sh` contains the string "source lib/telemetry.sh".
  Verification: make test
