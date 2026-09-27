<!-- plan: status=parked risk=normal accepted=2026-09-26T21:04:02Z routed-from=slow-unit:hngh-cadence-hour.service  cause=obsolete disposed=2026-09-27T00:00:13Z reason=identity re-occurred 3 times without landing; operator escalation stands -->
<!-- attempt: 2 -->
<!-- expires: 2026-10-03T21:00:13Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-09-26 — routed candidate

Routed by scripts/router-tick.py from alert identity `slow-unit:hngh-cadence-hour.service`
at 2026-09-26T21:00:13Z. Alert text: [oversight] slow-unit: hngh-cadence-hour.service wall=405.3s median=197.6s ×9

## Steps

- [ ] Delve: open research subject fail-20260926-slow-unit-hngh-cadence-hour.service for slow-unit:hngh-cadence-hour.service; record disposition; then fix or park
      Verification: research subject fail-20260926-slow-unit-hngh-cadence-hour.service present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-26T22:00:13Z re-occurred (dedup window expired)
- 2026-09-26T23:00:13Z re-occurred (dedup window expired)
- 2026-09-27T00:00:13Z re-occurred (dedup window expired)
