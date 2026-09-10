<!-- plan: status=accepted risk=normal accepted=2026-09-10T10:01:05Z routed-from=ux-review:dashboard-logs:rerenderOp-calls-renderLogs-directly-in -->
# 2026-09-10 — routed candidate

Routed by scripts/router-tick.py from alert identity `ux-review:dashboard-logs:rerenderOp-calls-renderLogs-directly-in`
at 2026-09-10T10:00:18Z. Alert text: `rerenderOp` calls `renderLogs` directly instead of invoking registered callbacks — bypasses view isolation and couples Logs to all views — hngh-automation.js fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-10T11:00:18Z re-occurred (dedup window expired)
