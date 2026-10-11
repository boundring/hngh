<!-- plan: status=accepted risk=normal accepted=2026-10-11T18:35:29Z routed-from=ram-gate:trip -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-18T18:00:14Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-11 — routed candidate

Routed by scripts/router-tick.py from alert identity `ram-gate:trip`
at 2026-10-11T18:00:14Z. Alert text: MemAvailable=1149MB < floor=2048MB (cadence-tick.sh skipped heavy work). SLA: re-fires per trip day, expires 24h after the last trip. Halt: none — pure telemetry, no retry loop behind the gate (the cadence/overnight halt itself is STOP=1). ×2

## Steps

- [ ] Delve: open research subject fail-20261011-ram-gate-trip for ram-gate:trip; record disposition; then fix or park
      Verification: research subject fail-20261011-ram-gate-trip present in research-subjects.txt with a recorded disposition; alert fixed or parked
