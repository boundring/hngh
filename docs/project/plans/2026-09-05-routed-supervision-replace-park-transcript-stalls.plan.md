<!-- plan: status=executed risk=normal accepted=2026-09-06T01:01:30Z resolved=2026-09-10T18:10Z routed-from=supervision-replace-park:transcript-stalls -->
# 2026-09-05 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision-replace-park:transcript-stalls`
at 2026-09-05T00:00:45Z. Alert text: parked (bounded-slice limit): transcript-derived agent-stall sessions get NO roguelike replacement — jobs/agent-supervision.py replace_stalled_bridge_run fires only for source=bridge runs; evidence: omp-impl-phase3-9d5ab9 (transcript-derived, NOT in bridge store which holds only run-1) exited 2026-09-04T23:14Z after a 7m-hung bash tool call (tool_execution_start 23:07Z with no completion event) yet re-alerted 'stalled' daily; fix landed 2026-09-04: session_exit marker now grounds the session terminal (no more stall rows); the auto die+replace for transcript sessions still needs a spawn policy + handoff source — operator should die+replace manually or re-provision via bridge ×2

## Steps

- [x] Investigate the alert, fix or park, with a named verification
      Verification: `make test` green in the owning repo
      Resolved 2026-09-10 (overnight-lead): no code change. The demanded
      spawn policy + handoff source landed 2026-09-06 as the
      watchdog->respawn composition: jobs/agent-watchdog.sh (5m tier)
      classifies stall/loop/hard-error and appends cause-classified
      `session-drop` rows to agent-handoffs.md; jobs/agent-respawn.sh
      (30m tier) consumes dead rows under bounded guards (steer-don't-kill
      by cause, 1/mission/day + respawn-max-attempts 2, respawn-daily-cap
      1 shared with logs/budget.md, launch via lib/launch-session.sh
      only). Ledger shows live dispositions (respawn-refused rows
      2026-09-08/09). Bare transcripts stay advisory by design: a
      transcript alone names no mission to respawn (an operator-interactive
      session must not be auto-replaced); stale ones evict via
      MAX_TRACKED_AGE_S. agent-supervision.py itself unchanged — the
      session_exit terminal fix from 2026-09-04 stands.
      Verification run: automation `make test` rc=0, including
      test-agent-supervision.py and test-agent-respawn.py; gate was red
      until d78a622 fixed the non-hermetic quota-routing test.
