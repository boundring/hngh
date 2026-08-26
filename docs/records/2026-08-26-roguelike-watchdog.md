# Roguelike agent watchdog — first concrete slice

**Date:** 2026-08-26
**Slice:** roguelike agentic lifecycle, watchdog — log-only observation + handoff.

The roguelike rule (`docs/project/roguelike-agentic.md`) says a session that
stalls, loops, or errors without recovery is dead; call it off, learn from
the failure, and launch a failure-informed replacement. This slice builds the
first concrete, observable piece: a **watchdog** that watches running agent
sessions, detects the three death signals against its locally readable
surface, and records a **log-only handoff** (a ledger line + an attention
flag) — it does not kill or launch agents yet. The actual replacement launch
is the next slice, carried by the handoff the watchdog leaves.

## Mount

The watchdog lives in `hngh-automation` (side-effect-free w.r.t. the kernel;
it reads `~/.omp/agent/sessions` and the live `~/.omp/run/daemons/*/clients`
roster, never mutates hngh state). It is folded into the existing **5m
oversight tick** probe leg (`jobs/oversight-tick.sh -> probe_agent_watchdog`
-> `jobs/agent-watchdog.sh`) rather than a new timer — the cadence machinery,
flock, `alert()` (report-queue + attention flag), and breadcrumbs are reused,
so there is no new systemd unit and nothing to enable.

## Detection surface (what the watchdog can honestly see)

- **Live rosters:** `~/.omp/run/daemons/*/clients/*` — one JSON per broker
  client, `{"pid","projectDir"}`. Gives the set of currently-open sessions.
- **Transcripts:** `~/.omp/agent/sessions/<slug>/<session>.jsonl` — every
  tool call / tool result / message is one JSON line with a timestamp.
- **Subagent liveness:** a session's per-agent transcripts live in its own
  subdir; a fresh one means the parent is legitimately parked on a live
  subagent.

### What it CANNOT see (stated honestly)

- The LM's in-flight "thinking". A stall is inferred only when a *current*
  session's transcript is silent for a full window **and** has no live
  subagent writing — a legit session sitting on a running subagent is never
  flagged (verified live).
- `projectDir` → sessions-slug is a path heuristic; an unmatched project is
  skipped (fail-open).

## Detection (defaults, env-overridable)

| Class | Signal | Default |
|-------|--------|---------|
| `stall` | current session's open turn (assistant text or non-`hub` tool call) with no transcript progress for `WATCHDOG_STALL_MIN` and no fresh subagent | 10 min |
| `loop` | trailing `WATCHDOG_LOOP_N` tool calls identical (guardrails failure class 1: blind tool-call retry) | 3 |
| `error` | trailing result is a hard-error result (`fail:`, `traceback`, …) with no corrective step for `WATCHDOG_ERROR_GRACE_MIN` | 2 min |

A session is only considered if its transcript was touched within
`WATCHDOG_LIVE_MIN` (default 180) — finished/abandoned sessions are not
re-flagged. Findings are deduped (`/tmp/hngh-watchdog-seen`) so the same
session+class is not re-reported on every 5m tick.

## On detection (log-only)

Appends a line to `agent-handoffs.md` (the running ledger), then files an
`alert` row via the hngh report-queue and touches
`/tmp/hngh-overseer-attention`, so the agentic steering leg / operator sees
it — then dedupes. **No processes are killed, no sessions are ended, no
replacement is launched in this slice.**

Ledger line format:

    session-drop | <ts> | <project-slug>|<session-id> | <class>: <evidence>

## Evidence

- Live no-false-positive run against the real trees (hngh session busy
  via a live subagent; hngh-automation session idle > 8 h) → **0 findings**,
  exit 0.
- Three planted fixtures (fake stalled / looped / errored sessions) → all
  three detected and logged as `session-drop` lines; report-queue alert
  invoked; attention flag armed; breadcrumbs written; dedupe confirmed.
- Fixture artifacts were then removed; the committed ledger ships with a
  header and is populated only by real future detections.

## Files

- `hngh-automation/jobs/agent-watchdog.sh` (new) — detector + handoff.
- `hngh-automation/jobs/oversight-tick.sh` — one-line mount on the probe leg.
- `hngh-automation/agent-handoffs.md` (new) — the running handoff ledger.
- This record, ceremony-committed in hngh.

## Next roadmap candidate

The actual replacement leg: on a `session-drop` handoff, end that session and
launch the failure-informed replacement (dancing-ui / gantt-ports backlog
lands there). This slice is deliberately log-only so a human/agentic leg
can trust the signal before any process control.