<!-- plan: status=proposed risk=normal accepted=- routed-from=ux-review:dashboard-logs:2-HnghPoll-start-ignores-the-opts-parame -->
# 2026-09-20 — routed candidate

Routed by scripts/router-tick.py from alert identity `ux-review:dashboard-logs:2-HnghPoll-start-ignores-the-opts-parame`
at 2026-09-20T10:00:28Z. Alert text: 2. `HnghPoll.start` ignores the `opts` parameter except for `interval`, leaving no way to configure backoff caps, initial delays, or pause conditions, which forces every view to duplicate timer logic or accept a single rigid 10s/60s schedule -> `hngh-automation/dashboard.js`. fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
