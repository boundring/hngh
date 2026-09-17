<!-- plan: status=parked risk=normal accepted=- routed-from=patrol:feeds  cause=obsolete disposed=2026-09-17T03:00:35Z reason=identity re-occurred 3 times without landing; operator escalation stands -->
# 2026-09-16 — routed candidate

Routed by scripts/router-tick.py from alert identity `patrol:feeds`
at 2026-09-16T00:00:19Z. Alert text: patrol feeds: feed-missing on dashboard/research-routes.json -- no feed file

## Steps

- [ ] Delve: open research subject fail-20260916-patrol-feeds for patrol:feeds; record disposition; then fix or park
      Verification: research subject fail-20260916-patrol-feeds present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-17T01:00:13Z re-occurred (dedup window expired)
- 2026-09-17T02:00:13Z re-occurred (dedup window expired)
- 2026-09-17T03:00:35Z re-occurred (dedup window expired)
