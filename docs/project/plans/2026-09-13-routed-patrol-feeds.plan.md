<!-- plan: status=parked risk=normal accepted=- routed-from=patrol:feeds  cause=obsolete disposed=2026-09-16T02:00:13Z reason=identity re-occurred 3 times without landing; operator escalation stands  cause=obsolete disposed=2026-09-17T07:00:26Z reason=identity re-occurred 4 times without landing; operator escalation stands -->
# 2026-09-13 — routed candidate

Routed by scripts/router-tick.py from alert identity `patrol:feeds`
at 2026-09-13T15:25:39Z. Alert text: patrol feeds: feed-stale on dashboard/operator-items.json -- age=1095s > 600s ×2

## Steps

- [ ] Delve: open research subject fail-20260913-patrol-feeds for patrol:feeds; record disposition; then fix or park
      Verification: research subject fail-20260913-patrol-feeds present in research-subjects.txt with a recorded disposition; alert fixed or parked

## Occurrences

- 2026-09-16T00:00:19Z re-occurred (dedup window expired)
- 2026-09-16T01:00:39Z re-occurred (dedup window expired)
- 2026-09-16T02:00:13Z re-occurred (dedup window expired)
- 2026-09-17T07:00:26Z re-occurred (dedup window expired)
