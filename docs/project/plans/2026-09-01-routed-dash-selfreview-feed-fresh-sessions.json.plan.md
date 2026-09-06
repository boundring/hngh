<!-- plan: status=executed risk=normal accepted=2026-09-01T12:01:27Z routed-from=dash-selfreview:feed-fresh:sessions.json -->
# 2026-09-01 — routed candidate

Routed by scripts/router-tick.py from alert identity `dash-selfreview:feed-fresh:sessions.json`
at 2026-09-01T12:00:47Z. Alert text: [dash-selfreview] feed-fresh:sessions.json: unacceptable-now — stale 1858s > 3x tier 60s — producer for sessions.json is not firing or is failing

## Steps

- [x] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
      Executed 2026-09-06T00:39Z (this wake — the cycle's delegated
      session for the step): investigated — no live defect remains; the
      finding was a real transient producer stall, correctly detected,
      recovered same day, never refired. Evidence: the alert fired
      2026-09-01T12:00:47Z when dashboard/sessions.json was last
      written 11:29:49Z (stale 1858s > 3x tier 60s). STATE.md
      breadcrumbs show the 1m drop-in (cadence/1m/10-sessions-feed.sh)
      mounting every minute through the stall window, so the failure
      was inside jobs/sessions-feed.py, which fail-closes silently —
      broken/missing readout.json is an early return leaving the prior
      sessions.json untouched, and any other crash exits with no
      breadcrumb; the adjacent 11:30:43Z refresh-dashboard.sh row
      "spine reader failed; leaving prior readout.json" records a
      reader failure in the same window. The exact 09-01 failure mode
      is not reconstructible from logs (silent by design); the detector
      chain worked end-to-end: self-review flagged it, router routed
      it, plan was accepted. No recurrence: report-queue shows the
      identity only as the 09-01 routing row (2e363cbd, x7, all within
      the routing window) — no later row in 5 days; the 1m producer is
      demonstrably healthy now (sessions.json regenerating every
      minute; generated=2026-09-06T00:33:03Z, 18 session rows at
      check). Verify (met): the finding's own check passes —
      `python3 jobs/dashboard-self-review.py` in hngh-automation exits
      0 all-clear (feed-fresh, feed-valid, served, ledger: zero
      findings, silent all-clear tick) at 2026-09-06T00:34Z;
      automation `make test` green (bash -n over cadence/jobs/lib/
      scripts, 10 test files + agent-supervision selfcheck 7 fixtures,
      identifier lint clean); hngh kernel `make test` green pre-commit
      (2855 checks passed) for this ceremony. No code change required —
      the self-review tick is the detector for exactly this failure
      mode and performed as designed.
