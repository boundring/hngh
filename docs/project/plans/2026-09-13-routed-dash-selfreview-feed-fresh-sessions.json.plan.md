<!-- plan: status=expired risk=normal accepted=- routed-from=dash-selfreview:feed-fresh:sessions.json  cause=fixed disposed=2026-09-13T18:15:00Z reason=producer restored by 12:40 EDT reboot; hngh-cadence-1m.timer enabled+active, sessions.json regenerating every minute, patrol feeds/feed-freshness:sessions.json PASS (age=26s) -->
# 2026-09-13 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:feed-fresh:sessions.json`
at 2026-09-13T15:25:39Z. Alert text: [dash-selfreview] feed-fresh:sessions.json: unacceptable-now — stale 8551s > 3x tier 60s — producer for sessions.json is not firing or is failing

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-13T18:15:00Z disposed (cause=fixed): the finding's own check
  (patrol feeds/feed-freshness:sessions.json) passes without a script
  change — the 1m cadence producer (automation/cadence/1m/10-sessions-feed.sh
  -> jobs/sessions-feed.py via hngh-cadence-1m.timer) is firing. Executing
  the fix step would be redundant; the systemd-units patrol added in
  commit e75360c guards the timer against recurrence.
- 2026-09-26T13:00:13Z re-occurred (dedup window expired)
