<!-- plan: status=executed risk=normal accepted=2026-09-12T09:02:15Z routed-from=deck-unreachable-2026-09-12 -->
# 2026-09-12 — routed candidate

Routed by scripts/router-tick.py from alert identity `deck-unreachable-2026-09-12`
at 2026-09-12T03:00:49Z. Alert text: deck was reachable earlier today but the pull now fails (probe rc=255)

## Steps

- [x] Delve: open research subject fail-20260912-deck-unreachable-2026-09-12 for deck-unreachable-2026-09-12; record disposition; then fix or park
      Verification: research subject fail-20260912-deck-unreachable-2026-09-12 present in research-subjects.txt with a recorded disposition; alert fixed or parked
      Closed 2026-09-14T12:40Z: disposition parked -- expected-state transient, no defect (intermittent peer contract, cadence/hour/32-deck-facts.sh:9-12; facts self-recovered 04:02Z same UTC day, gaps healed within the day, deck-facts files continue 09-13/09-14; no live report-queue row remains). Subject + disposition rows carry the evidence.
      Verification: research subject fail-20260912-deck-unreachable-2026-09-12 present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-12T04:00:49Z re-occurred (dedup window expired)
