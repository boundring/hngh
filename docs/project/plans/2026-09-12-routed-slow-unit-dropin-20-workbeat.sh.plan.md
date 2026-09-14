<!-- plan: status=executed risk=normal accepted=2026-09-12T20:32:27Z routed-from=slow-unit:dropin:20-workbeat.sh -->
# 2026-09-12 — routed candidate

Routed by scripts/router-tick.py from alert identity `slow-unit:dropin:20-workbeat.sh`
at 2026-09-12T20:00:35Z. Alert text: [oversight] slow-unit: dropin:20-workbeat.sh wall=1964.6s median=40.3s ×6

## Steps

- [x] Delve: open research subject fail-20260912-slow-unit-dropin-20-workbeat.sh for slow-unit:dropin:20-workbeat.sh; record disposition; then fix or park
      Verification: research subject fail-20260912-slow-unit-dropin-20-workbeat.sh present in research-subjects.txt with a recorded disposition; alert fixed or parked -- met 2026-09-14: disposition adopted (research-dispositions.tsv row 121, crystallized as docs/research/2026-09-14-fail-20260912-slow-unit-dropin-20-workbeat.sh.md) and the fix landed: ENVELOPE 1800+600+60=2460s for dropin:20-workbeat.sh AND hngh-overnight.service (jobs/slow-units.py, tests/test-slow-units.py failing-first: 1964.6s alert wall + 2384.771s ledger max now in-envelope, 11/11 green; live ledger probe exit 0)
