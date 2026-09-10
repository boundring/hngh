<!-- plan: status=accepted risk=normal accepted=2026-09-10T10:01:05Z routed-from=ux-review:dashboard-logs:fetchOpState-silently-swallows-network -->
# 2026-09-10 — routed candidate

Routed by scripts/router-tick.py from alert identity `ux-review:dashboard-logs:fetchOpState-silently-swallows-network`
at 2026-09-10T10:00:18Z. Alert text: `fetchOpState` silently swallows network errors via `.catch(function () { return null; })` — masks data loss as "feed unavailable" without logging or state flag — hngh-automation.js fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-10T11:00:18Z re-occurred (dedup window expired)
- 2026-09-10T12:00:18Z re-occurred (dedup window expired)
