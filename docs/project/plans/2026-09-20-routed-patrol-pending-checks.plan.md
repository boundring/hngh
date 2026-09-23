<!-- plan: status=parked risk=normal accepted=- routed-from=patrol:pending-checks  cause=obsolete disposed=2026-09-23T02:00:13Z reason=identity re-occurred 3 times without landing; operator escalation stands -->
# 2026-09-20 — routed candidate

Routed by scripts/router-tick.py from alert identity `patrol:pending-checks`
at 2026-09-20T15:00:13Z. Alert text: patrol pending-checks: check-pending on correction-f6 -- check:correction-f6 awaiting promotion (tier 30m): something looks off ×6

## Steps

- [ ] Delve: open research subject fail-20260920-patrol-pending-checks for patrol:pending-checks; record disposition; then fix or park
      Verification: research subject fail-20260920-patrol-pending-checks present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-22T05:00:22Z re-occurred (dedup window expired)
- 2026-09-22T06:00:22Z re-occurred (dedup window expired)
- 2026-09-23T02:00:13Z re-occurred (dedup window expired)
