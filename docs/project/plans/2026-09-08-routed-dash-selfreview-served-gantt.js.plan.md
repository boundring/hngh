<!-- plan: status=parked risk=normal accepted=2026-09-08T04:32:07Z routed-from=dash-selfreview:served:gantt.js  cause=obsolete disposed=2026-09-09T15:27:53Z reason="premise resolved: automation/dashboard/gantt.js now exists (alert was HTTP 404 File not found); siblings app.js/schedule-view.js resolved identically"-->
# 2026-09-08 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:served:gantt.js`
at 2026-09-08T04:00:34Z. Alert text: [dash-selfreview] served:gantt.js: unacceptable-now — http://127.0.0.1:8890/gantt.js unreachable (HTTP Error 404: File not found) — is hngh-dashboard.service up?

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
