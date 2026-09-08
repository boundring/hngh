<!-- plan: status=parked risk=normal accepted=2026-09-08T04:32:07Z routed-from=dash-selfreview:served:schedule-view.js  cause=obsolete disposed=2026-09-08T07:00:34Z reason=identity re-occurred 3 times without landing; operator escalation stands -->
# 2026-09-08 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:served:schedule-view.js`
at 2026-09-08T04:00:34Z. Alert text: [dash-selfreview] served:schedule-view.js: unacceptable-now — http://127.0.0.1:8890/schedule-view.js unreachable (HTTP Error 404: File not found) — is hngh-dashboard.service up?

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green

## Occurrences

- 2026-09-08T05:00:34Z re-occurred (dedup window expired)
- 2026-09-08T06:00:34Z re-occurred (dedup window expired)
- 2026-09-08T07:00:34Z re-occurred (dedup window expired)
- 2026-09-08T08:00:34Z re-occurred (dedup window expired)
- 2026-09-08T09:00:34Z re-occurred (dedup window expired)
