<!-- plan: status=accepted risk=normal accepted=2026-09-25T02:03:34Z routed-from=crumbs-mirror:rows -->
# 2026-09-25 — routed candidate

Routed by scripts/router-tick.py from alert identity `crumbs-mirror:rows`
at 2026-09-25T01:00:13Z. Alert text: crumbs mirror flip SLA: auto-park the flip with cause parity-unmet if no clean parity day by 2026-10-01; halt: if the mismatch deficit grows past 3, file a report row and stop the writer side instead of waiting for parity (fresh verify: verdict=ok rows=166002-importable=166002) ×3

## Steps

- [ ] Delve: open research subject fail-20260925-crumbs-mirror-rows for crumbs-mirror:rows; record disposition; then fix or park
      Verification: research subject fail-20260925-crumbs-mirror-rows present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-25T02:00:13Z re-occurred (dedup window expired)
