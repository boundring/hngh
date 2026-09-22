<!-- plan: status=parked risk=normal accepted=2026-09-22T14:03:14Z routed-from=dash-selfreview:served:app.js  cause=obsolete disposed=2026-09-22T16:43:29Z reason=identity re-occurred 3 times without landing; operator escalation stands -->
# 2026-09-22 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:served:app.js`
at 2026-09-22T14:00:12Z. Alert text: [dash-selfreview] served:app.js: unacceptable-now — http://127.0.0.1:8890/app.js unreachable (<urlopen error [Errno 111] Connection refused>) — is hngh-dashboard.service up?

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-22T15:01:03Z re-occurred (dedup window expired)
- 2026-09-22T16:00:13Z re-occurred (dedup window expired)
- 2026-09-22T16:43:29Z re-occurred (dedup window expired)
- 2026-09-22T16:48:11Z re-occurred (dedup window expired)
- 2026-09-22T17:00:14Z re-occurred (dedup window expired)
