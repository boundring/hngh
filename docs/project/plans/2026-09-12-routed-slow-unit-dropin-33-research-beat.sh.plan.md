<!-- plan: status=executed risk=normal accepted=2026-09-12T09:02:15Z routed-from=slow-unit:dropin:33-research-beat.sh -->
# 2026-09-12 — routed candidate

Routed by scripts/router-tick.py from alert identity `slow-unit:dropin:33-research-beat.sh`
at 2026-09-12T05:00:49Z. Alert text: [oversight] slow-unit: dropin:33-research-beat.sh wall=137.4s median=0.2s ×10

## Steps

- [x] Delve: open research subject fail-20260912-slow-unit-dropin-33-research-beat.sh for slow-unit:dropin:33-research-beat.sh; record disposition; then fix or park
      Verification: research subject fail-20260912-slow-unit-dropin-33-research-beat.sh present in research-subjects.txt with a recorded disposition; alert fixed or parked
      Resolved 2026-09-14: subject added to research-subjects.txt, disposition "adopted -- fixed" in research-dispositions.tsv; fix = ENVELOPE entry (800+60s) in automation/jobs/slow-units.py with failing test first (tests/test-slow-units.py 11/11 green, make test green); closes the identity re-routed 5x since 2026-09-08, supersedes the same-class park per the 16-remote-push envelope precedent (2362f89).
