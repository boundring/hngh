# 2026-09-04 — Transcript stalls never replace (supervision gap, grounded)

## What the digest showed

The 2026-09-04 digest carried the same agent-stall alert for
`omp-impl-phase3-9d5ab9` again (and siblings), while the router had been
re-drafting duplicate one-stepper plans for stalled sessions across days.

## Grounding (what the evidence actually said)

- The session id is transcript-derived (`omp-<stem>-<md5>`), not a bridge
  run — `bridge/record.lisp` holds only `run-1`.
- The transcript ends with a 7-minute-hung bash tool call
  (`tool_execution_start` 2026-09-04T23:07:07Z, no completion event) and
  a `session_exit` custom event at 23:14:07Z. The session is dead.
- `jobs/agent-supervision.py` `replace_stalled_bridge_run` fires ONLY for
  `source == "bridge"` sessions (in-code rule, tick()); a
  transcript-derived stall is advisory forever, so nothing ever replaced
  the dead session and the alert re-fired daily (identity window 86400).
- Worse: the final assistant turn asked the operator something, so
  `awaiting_stall` overrode the natural terminal classification — a
  DEAD session kept being reported as "stalled (awaiting-operator)".

## What landed (2026-09-04, hngh-automation)

1. `scan_transcript` now returns `exited` (session_exit marker in the
   final line) and `omp_sessions` treats exited sessions as terminal:
   no more stall alerts for dead sessions, and the stalled→"recovered"
   flap row is suppressed for them.
2. The roguelike replace path stays bridge-only. Automatic die+replace
   for transcript sessions is PARKED (report-queue row
   `supervision-replace-park:transcript-stalls`): it needs a spawn
   policy and a handoff source that a bare transcript does not carry.
3. Router dedup (same ticket): router-tick.py no longer re-drafts a
   routed plan while a non-terminal one for the same subject is younger
   than HNGH_ROUTER_DEDUP_HOURS (default 12h), and escalates >=3 dedups
   per day to operator visibility.

## Lesson

A supervision rule that classifies liveness must read the session's own
end-of-life marker before inferring intent from silence. Silence + an
old ask is ambiguous between "waiting for the operator" and "already
exited" — the exit marker disambiguates, and anything else fail-closed
toward alerting (noisy but honest) is preferable to silent.