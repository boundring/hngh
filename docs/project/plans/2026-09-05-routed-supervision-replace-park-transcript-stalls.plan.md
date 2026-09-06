<!-- plan: status=accepted risk=normal accepted=2026-09-06T01:01:30Z routed-from=supervision-replace-park:transcript-stalls -->
# 2026-09-05 — routed candidate

Routed by scripts/router-tick.py from alert identity `supervision-replace-park:transcript-stalls`
at 2026-09-05T00:00:45Z. Alert text: parked (bounded-slice limit): transcript-derived agent-stall sessions get NO roguelike replacement — jobs/agent-supervision.py replace_stalled_bridge_run fires only for source=bridge runs; evidence: omp-impl-phase3-9d5ab9 (transcript-derived, NOT in bridge store which holds only run-1) exited 2026-09-04T23:14Z after a 7m-hung bash tool call (tool_execution_start 23:07Z with no completion event) yet re-alerted 'stalled' daily; fix landed 2026-09-04: session_exit marker now grounds the session terminal (no more stall rows); the auto die+replace for transcript sessions still needs a spawn policy + handoff source — operator should die+replace manually or re-provision via bridge ×2

## Steps

- [ ] Investigate the alert, fix or park, with a named verification
      Verification: `make test` green in the owning repo
