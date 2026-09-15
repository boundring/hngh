<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-15 - dev-fail-20260914-Do-host-level-telemetry-ou (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the fail-20260914-Do-host-level-telemetry-outside-the-line research line by establishing a probe-and-classify procedure for host-level telemetry survival without modifying kernel or credential surfaces.

## Steps

- [ ] Create `lib/telemetry_probe.sh` to define the three-class probe-and-classify procedure for sysstat, journald OOM entries, and cron logs.
  Verification: bash -n lib/telemetry_probe.sh
- [ ] Add `tests/test_telemetry_probe.sh` to verify the classification logic distinguishes between structurally absent and rotated telemetry classes.
  Verification: make test
- [ ] Create `scripts/classify_defect_vs_transient.sh` to apply the probe results for retroactive defect-vs-transient classification of the 2026-09-12 window.
  Verification: bash -n scripts/classify_defect_vs_transient.sh
- [ ] Add `tests/test_classify_logic.sh` to ensure the classification script correctly handles the unresolved empirical question without asserting a final verdict.
  Verification: make test
