<!-- plan: status=parked risk=normal accepted=- routed-from=ux-review:dashboard-logs:3-ageChip-and-ago-compute-elapsed-time-r  cause=obsolete disposed=2026-09-20T13:00:20Z reason=identity re-occurred 3 times without landing; operator escalation stands -->
# 2026-09-20 — routed candidate

Routed by scripts/router-tick.py from alert identity `ux-review:dashboard-logs:3-ageChip-and-ago-compute-elapsed-time-r`
at 2026-09-20T10:00:28Z. Alert text: 3. `ageChip` and `ago` compute elapsed time relative to `Date.now()` at render time rather than the fetch timestamp, causing displayed ages to drift forward on every poll without re-fetching data, which misrepresents the literal fact of when the state was captured -> `hngh-automation/dashboard.js`. fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-20T11:00:26Z re-occurred (dedup window expired)
- 2026-09-20T12:00:13Z re-occurred (dedup window expired)
- 2026-09-20T13:00:20Z re-occurred (dedup window expired)
