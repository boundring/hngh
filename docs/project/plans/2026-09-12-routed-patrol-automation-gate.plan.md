<!-- plan: status=executed risk=normal accepted=2026-09-12T21:03:16Z routed-from=patrol:automation-gate -->
# 2026-09-12 — routed candidate

Routed by scripts/router-tick.py from alert identity `patrol:automation-gate`
at 2026-09-12T21:00:23Z. Alert text: patrol automation-gate: gate-stale on hngh-automation -- no gate crumb found

## Steps

- [x] Delve: open research subject fail-20260912-patrol-automation-gate for patrol:automation-gate; record disposition; then fix or park
      Verification: research subject fail-20260912-patrol-automation-gate present in research-subjects.txt with a recorded disposition; alert fixed or parked
      Done 2026-09-14T13:07Z: subject + parked disposition appended (automation/research-subjects.txt, research-dispositions.tsv). Gate re-run green rc=0 ALL PASS; 2026-09-12 no-crumb state was transient (crumb cadence resumed 09-13 gate-green)

## Occurrences

- 2026-09-12T22:00:49Z re-occurred (dedup window expired)
