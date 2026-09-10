<!-- plan: status=accepted risk=normal accepted=2026-09-10T04:31:26Z routed-from=ux-review:dashboard-logs:3-fetchOpState-silently-swallows-network -->
# 2026-09-10 — routed candidate

Routed by scripts/router-tick.py from alert identity `ux-review:dashboard-logs:3-fetchOpState-silently-swallows-network`
at 2026-09-10T04:00:18Z. Alert text: 3. `fetchOpState` silently swallows network errors with `.catch(function () { return null; })`, leaving `opState.items` as `null` indefinitely, which forces the UI into "legacy digest bullets" mode without any visible error indicator or retry mechanism -> violates "quiet, evidence-first" by hiding the failure of the primary data source behind a fallback that looks like success -> `hngh-automation.js`. fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-10T05:00:18Z re-occurred (dedup window expired)
- 2026-09-10T06:00:18Z re-occurred (dedup window expired)
