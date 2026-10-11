<!-- plan: status=accepted risk=normal accepted=2026-10-11T10:06:05Z routed-from=arc-to-slice:typed-unavailable -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-18T10:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-11 — routed candidate

Routed by scripts/router-tick.py from alert identity `arc-to-slice:typed-unavailable`
at 2026-10-11T10:00:42Z. Alert text: arc-to-slice: typed lane unavailable (no TYPESAFE_API_KEY); 6 dispositioned arc(s) left unconverted; retry next tick. SLA: 7d window then lapse -- max one alert per week while the key is gone, lane self-ends when the key returns. Halt: 7d identity dedupe, no piling on ticks

## Steps

- [ ] Delve: open research subject fail-20261011-arc-to-slice-typed-unavailable for arc-to-slice:typed-unavailable; record disposition; then fix or park
      Verification: research subject fail-20261011-arc-to-slice-typed-unavailable present in research-subjects.txt with a recorded disposition; alert fixed or parked
