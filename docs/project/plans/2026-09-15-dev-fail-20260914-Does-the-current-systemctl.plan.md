<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-15 - dev-fail-20260914-Does-the-current-systemctl (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the instrumentation gap identified in the research line "Does the current systemctl status or equivalent execution log for the hngh-automation crumb writer show a failure state or last-run timestamp prior to 2026-09-12T21:03Z?", which found that manual observation is required due to missing automatic detection mechanisms.

## Steps

- [ ] Create `scripts/crumb-writer-health-check.sh` that reads the crumb writer's last-run timestamp file and compares it against a 24-hour staleness threshold, exiting non-zero if stale
  Verification: bash -n scripts/crumb-writer-health-check.sh

- [ ] Add a unit test in `tests/test-crumb-writer-health.sh` that mocks a stale timestamp file and asserts the health check script exits with failure status
  Verification: make test

- [ ] Create `cadence/crumb-writer-staleness-probe.sh` that invokes the health check script and writes a structured JSON result to stdout for machine consumption
  Verification: bash -n cadence/crumb-writer-staleness-probe.sh

- [ ] Add a digest entry in `digest/CRUMB-WRITER-STALENESS-INSTRUMENTATION.md` documenting the new probe's purpose, invocation contract, and expected output schema
  Verification: grep -q "staleness" digest/CRUMB-WRITER-STALENESS-INSTRUMENTATION.md

- [ ] Update `lib/crumb-writer-utils.sh` to expose a `get_last_run_timestamp()` function that parses the timestamp file format used by the crumb writer
  Verification: bash -n lib/crumb-writer-utils.sh
