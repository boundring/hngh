<!-- plan: status=accepted risk=normal accepted=2026-09-22T13:03:06Z routed-from=dash-selfreview:served:schedule-view.js -->
# 2026-09-20 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:served:schedule-view.js`
at 2026-09-20T21:23:45Z. Alert text: [dash-selfreview] served:schedule-view.js: unacceptable-now — http://127.0.0.1:8890/schedule-view.js unreachable (<urlopen error [Errno 111] Connection refused>) — is hngh-dashboard.service up?

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
