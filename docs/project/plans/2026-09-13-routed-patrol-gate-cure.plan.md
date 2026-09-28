<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z routed-from=patrol:gate-cure -->
# 2026-09-13 — routed candidate

Routed by scripts/router-tick.py from alert identity `patrol:gate-cure`
at 2026-09-13T20:00:19Z. Alert text: patrol gate-cure: gate-cure-refused on kernel -- ceremony-drive rc=1: ×2

## Steps

- [x] Delve: open research subject fail-20260913-patrol-gate-cure for patrol:gate-cure; record disposition; then fix or park
      Verification: research subject fail-20260913-patrol-gate-cure present in research-subjects.txt with a recorded disposition; alert fixed or parked
      Done 2026-09-28: subject appended to research-subjects.txt; disposition parked (fixed-transient) in research-dispositions.tsv; record docs/research/2026-09-28-fail-20260913-patrol-gate-cure.md. Surface verified: loop-history guard rc=0 (153 commits, 27 exemptions, 0 violations); no gate-cure-refused alert rows since 2026-09-14.

## Occurrences

- 2026-09-13T21:00:39Z re-occurred (dedup window expired)
