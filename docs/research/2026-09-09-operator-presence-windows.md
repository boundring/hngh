# 2026-09-09 — operator presence windows: Wednesday archery absence

Operator stated routine (2026-09-09): every Wednesday evening they are at archery practice and unavailable for prompt responses until just after 10pm Eastern Daylight Time (EDT). The machine's reference clock is UTC, so the window converts to approximately Wednesday 22:00Z through Thursday 02:05Z. This is a recurring weekly absence, not a one-off.

## Window definition

| Field | Value |
|---|---|
| **Key** | `operator-away-windows` in cadence-params.tsv |
| **Value** | `Wed 22:00Z-Thu 02:05Z` |
| **Provenance** | `automation/cadence/day/34-operator-presence-check.sh (weekly archery practice, 2026-09-09)` |
| **Meaning** | During this window the operator cannot answer prompts; one-word-answerable operator-items queue instead of expecting fast turnaround |

This generalizes the deck-availability pattern established in stall-recovery-and-operator-surfaces plan step 8 (`docs/design/rehearsal-and-self-order.md`: deck-unreachable probes use cadence params to know when unreachable state is expected rather than alarming). Here the same principle applies to the human operator instead of the desktop node.

## Consumers (scripts that should read this row)

1. **`automation/jobs/agent-watchdog.sh`** — flags awaiting-operator stalls via its `watchdog-live-min` tunable (currently 180m from cadence-params.tsv). When a session transcript shows it asked the operator something (matched ASK_RE patterns like "should I", "shall I", "waiting for"), the watchdog should check whether the current UTC time falls within the operator-away-windows before flagging. During the window, such sessions are expected to be quiet.

2. **`automation/jobs/agent-supervision.py`** — implements the `awaiting_stall()` classification (line 143) which fires when a session has been quiet past `STALL_MINUTES`. The supervisor tick should gate this check against the presence window: an awaiting-operator session during Wednesday 22:00Z–Thursday 02:05Z is not stalled, it is waiting as expected.

3. **`automation/cadence/hour/16-remote-push.sh`** — reads cadence params for scheduling decisions; would benefit from knowing when to defer operator-facing push confirmations until the next business day.

4. **`automation/scripts/router-tick.py`** — routes alerts and supervisory findings to operator-items; could suppress or deprioritize awaiting-operator items that fire during the known absence window, filing them with `cause=operator-absent` instead of `cause=stalled`.

## Implementation note

No script currently reads the `operator-away-windows` key. Adding the TSV row makes it discoverable to any consumer that uses `get_param` (which works on all existing cadence-param rows). Actual behavioral changes require callers to add the lookup — this file documents both the data and who should consume it.
