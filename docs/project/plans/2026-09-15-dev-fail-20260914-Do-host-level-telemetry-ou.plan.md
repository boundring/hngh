<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-15 - dev-fail-20260914-Do-host-level-telemetry-ou (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the fail-20260914-Do-host-level-telemetry-outside-the-line research line by establishing a probe-and-classify procedure for host-level telemetry survival, enabling retroactive defect-vs-transient classification without waiting for controlled retests.

## Steps

- [ ] Create `scripts/probe_telemetry_survival.sh` to check for sysstat/sar archives, journald OOM entries, and cron logs within the 2026-09-12 window
  Verification: bash -n scripts/probe_telemetry_survival.sh

- [ ] Add `lib/telemetry_classifier.py` to classify telemetry findings into defect-vs-transient categories based on survival status
  Verification: python3 lib/telemetry_classifier.py --help

- [ ] Create `tests/test_telemetry_probe.sh` to verify the probe script handles missing telemetry sources gracefully
  Verification: bash tests/test_telemetry_probe.sh

- [ ] Add `digest/TELEMETRY_SURVIVAL_REPORT.md` documenting the three-class probe-and-classify procedure and structural asymmetry findings
  Verification: grep -q "three-class" digest/TELEMETRY_SURVIVAL_REPORT.md

- [ ] Create `scripts/classify_retroactive.sh` to apply the classification logic to archived telemetry data from the 2026-09-12 window
  Verification: bash -n scripts/classify_retroactive.sh
