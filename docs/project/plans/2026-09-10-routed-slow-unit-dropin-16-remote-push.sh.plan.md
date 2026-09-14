<!-- plan: status=executed risk=normal accepted=2026-09-10T03:01:05Z routed-from=slow-unit:dropin:16-remote-push.sh -->
# 2026-09-10 — routed candidate

Routed by scripts/router-tick.py from alert identity `slow-unit:dropin:16-remote-push.sh`
at 2026-09-10T03:00:18Z. Alert text: [oversight] slow-unit: dropin:16-remote-push.sh wall=23.1s median=0.0s ×12

## Steps

- [x] Delve: open research subject fail-20260910-slow-unit-dropin-16-remote-push.sh for slow-unit:16-remote-push.sh; record disposition; then fix or park
      Verification: research subject fail-20260910-slow-unit-dropin-16-remote-push.sh present in research-subjects.txt with a recorded disposition; alert fixed or parked
      Resolved 2026-09-14: subject added to research-subjects.txt, disposition "adopted -- fixed" in research-dispositions.tsv, doc docs/research/2026-09-14-fail-20260910-slow-unit-dropin-16-remote-push.sh.md; fix = ENVELOPE entry (290+60) in automation/jobs/slow-units.py with failing test first (tests/test-slow-units.py 9/9 green).
      Verification: research subject fail-20260910-slow-unit-dropin-16-remote-push.sh present in research-subjects.txt with a recorded disposition; alert fixed or parked
