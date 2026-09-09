<!-- plan: status=parked risk=normal accepted=2026-09-08T04:32:07Z routed-from=dash-selfreview:feed-valid:time-ledger.json  cause=obsolete disposed=2026-09-09T15:27:53Z reason="premise resolved: automation/dashboard/time-ledger.json now exists (the alert was 'No such file'); STATE.md shows time-ledger.sh refreshing it repeatedly"-->
# 2026-09-08 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:feed-valid:time-ledger.json`
at 2026-09-08T02:43:12Z. Alert text: [dash-selfreview] feed-valid:time-ledger.json: unacceptable-now — unparsable: [Errno 2] No such file or directory: '/home/bricker/Projects/etc/hngh/automation/dashboard/time-ledger.json'

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-08T03:00:34Z re-occurred (dedup window expired)
