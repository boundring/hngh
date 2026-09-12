<!-- plan: status=executed risk=normal accepted=2026-09-07T23:01:07Z routed-from=slow-unit:dropin:50-research-overflow.sh -->
# 2026-09-07 — routed candidate

Routed by scripts/router-tick.py from alert identity `slow-unit:dropin:50-research-overflow.sh`
at 2026-09-07T23:00:12Z. Alert text: [oversight] slow-unit: dropin:50-research-overflow.sh wall=258.9s median=0.0s ×6

## Steps

- [x] Delve: open research subject fail-20260907-slow-unit-dropin-50-research-overflow.sh for slow-unit:dropin:50-research-overflow.sh; record disposition; then fix or park
      Verification: research subject fail-20260907-slow-unit-dropin-50-research-overflow.sh present in research-subjects.txt with a recorded disposition; alert fixed or parked
      Verification: research subject fail-20260907-slow-unit-dropin-50-research-overflow.sh present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-08T00:00:26Z re-occurred (dedup window expired)
- 2026-09-08T01:00:36Z re-occurred (dedup window expired)

## Disposition (2026-09-12, session-executed)

Research subject opened (research-subjects.txt) and dispositioned `parked` (research-dispositions.tsv, 2026-09-12): wall=258.9s vs 0.0s median is by design — failfirst-GO ticks pay one pinned model call (~200-260s) while throttled ticks return instantly; the pacer (FAILFIRST_TICK_S=900) owns degradation. Revisit only if wall exceeds ~2x the model-call ceiling without a GO verdict. Side fix on the same surface: automation gate was red on unrelated test-hngh-packages.py PATH-divergence failures; registry install-paths moved to PATH-independent absolute forms (config/hngh-packages.tsv); `make test` green after the fix.
