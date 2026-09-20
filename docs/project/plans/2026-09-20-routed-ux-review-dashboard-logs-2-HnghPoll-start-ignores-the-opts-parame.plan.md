<!-- plan: status=parked risk=normal accepted=- routed-from=ux-review:dashboard-logs:2-HnghPoll-start-ignores-the-opts-parame  cause=obsolete disposed=2026-09-20T13:00:20Z reason=identity re-occurred 3 times without landing; operator escalation stands -->
# 2026-09-20 — routed candidate

Routed by scripts/router-tick.py from alert identity `ux-review:dashboard-logs:2-HnghPoll-start-ignores-the-opts-parame`
at 2026-09-20T10:00:28Z. Alert text: 2. `HnghPoll.start` ignores the `opts` parameter except for `interval`, leaving no way to configure backoff caps, initial delays, or pause conditions, which forces every view to duplicate timer logic or accept a single rigid 10s/60s schedule -> `hngh-automation/dashboard.js`. fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-20T11:00:26Z re-occurred (dedup window expired)
- 2026-09-20T12:00:13Z re-occurred (dedup window expired)
- 2026-09-20T13:00:20Z re-occurred (dedup window expired)
