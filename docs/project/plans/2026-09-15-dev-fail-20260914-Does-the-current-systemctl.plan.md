<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-15 - dev-fail-20260914-Does-the-current-systemctl (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the research line `fail-20260914-Does-the-current-systemctl-status-or-equ` by adding a machine-checkable staleness probe to close the identified instrumentation gap, ensuring crumb writer failure states are detected automatically rather than via manual observation.

## Steps

- [ ] Create `scripts/crumb-staleness-probe.sh` that reads the crumb file's modification time and compares it against a 24-hour threshold
  Verification: bash -n scripts/crumb-staleness-probe.sh
- [ ] Add a unit test in `tests/test_crumb_staleness.sh` that mocks an old timestamp to verify the probe exits non-zero on staleness
  Verification: make test
- [ ] Create `cadence/staleness-check.yaml` defining the cadence interval and failure criteria for the crumb writer
  Verification: grep -q "interval:" cadence/staleness-check.yaml
- [ ] Add a digest entry in `digest/RESEARCH-BEAT-staleness-probe.md` documenting the new probe's purpose and verification method
  Verification: test -f digest/RESEARCH-BEAT-staleness-probe.md
