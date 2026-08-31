# steer-vs-die thresholds: an observable rubric for the "learning or burning" judgment

Status: crystallized 2026-08-31 (authored 2026-08-31, riding the 2026-08-30 evening selfdev plan) from research line
`steer-vs-die-threshold`; per-beat material lives in hngh-automation digest/RESEARCH-BEAT-2026-08-30-steer-vs-die-threshold.md.

## Executive framing

`docs/project/roguelike-agentic.md` states the judgment — *is this agent learning, or just burning? If the next step is a
correct small step under budget → let it run. If it's looping, re-failing, or about to spend tokens on something we know
how to do procedurally → die and replace* — but leaves the triggers implicit. This record scopes each trigger to an
observable condition that is already detectable by the filed alert classes in `docs/project/reports.md` and by the
behaviors of `hngh-automation/jobs/agent-watchdog.sh`, and maps each to one response: **steer** (live corrective on a
mid-flight, progressing session), **procedural hook** (predicted next turn replaced by a token-cheap scripted call, per
the "procedural over agentic" rule), or **die+replace** (end session, failure-informed brief, launch successor).

The watchdog is LOG-ONLY: it records a handoff ledger line + alert + attention flag and does not kill or launch agents;
ending-the-session is a decision an operator/agentic leg acts on (its header says so explicitly). The table therefore
assigns responses, not automations.

## The rubric

| Signal | Observable trigger (grounded) | Response |
| --- | --- | --- |
| Loop repetition | Watchdog class `loop`: trailing `LOOP_N=3` assistant tool calls with identical name **and** serialized identical arguments (`scan` prints `identical tool call x3`). Field evidence of the sibling pattern: `loop-signal` alerts "STATE 3x identical crumb ... (3 markers in 5m)" (reports.md rows 2026-08-26T16:57:47Z 77c23af0, 2026-08-26T22:39:25Z cf2fc04a). | steer once (single corrective nudge); if the identical call reappears after steering, die+replace with a brief naming the stuck call. |
| Unrecovered error | Watchdog class `error`: last transcript record is a `toolResult` whose text matches `errish()` (traceback/fatal/exception/error:/failed/...) and quiet time exceeds `ERROR_GRACE_MIN=2` without a corrective step (`hard error result, no corrective step`). Reports.md shows the corresponding recovery pair pattern (alert then `recovered` progress, e.g. rows 2026-08-30T04:45:44Z acd0de86 / 04:50:44Z e51e5788). | die+replace immediately if no corrective step lands within the grace window; the roguelike rule makes "any error ... a good reason to call off and respawn" and forbids nursing the corpse. |
| Tool-calling spiral | Watchdog class `stall`: open assistant toolCall/text turn quiet for `STALL_MIN=10` minutes with **no** fresh subagent transcript writing — i.e. turn burning without visible progress (prints `no tool progress for Ndm`). Field evidence: `agent-stall` alerts "stalled, last tool-call 1967m ago" (2026-08-30T04:45:44Z) and "31m ago ×4" (2026-08-30T16:10:44Z) — the ×4 supersession shows the first window is still recoverable. | steer on the first window (session may be legitimately mid-flight — watchdog deliberately never flags a session with a live subagent); die+replace when the stall repeats ×N (the ×4 pattern) or steering once has already failed to unstick it (roguelike-agentic provenance: 2026-08-26 WebDashboard stall, "steering once failed to unstick it"). |
| Procedural hook availability | The next turn's action is predictable and token-cheap procedurally — the exact condition roguelike-agentic.md's hook section describes ("when we can predict what an agent's next turn would do, and there's a token-cheap procedural alternative"). The hook surface already exists and is machine-observable: watchdog `ingest` writes a `session-drop` line to `agent-handoffs.md`, files a report-queue alert, and touches `/tmp/hngh-overseer-attention` (ATTENTION_FLAG); the "attention signal / predictable-next-turn triggers the hook" leg is wired. | procedural hook: end the session at the turn boundary, run the known file write / script / probe directly, complete evaluation of partial work, launch the replacement with the brief — never spend agent tokens on the predicted call. |
| Budget burn rate | **Not established as an alert class.** Reports.md contains no budget-burn alerts; the only budget surface is the daily `budget digest` progress row (`overnight sessions=0 remote_model_calls=0 remote_cost_usd=0 [vs operator target $10-20/day]`, rows 2026-08-29/30/31) and the `slow-unit` alert `dropin:20-workbeat.sh wall=229.4s median=0.2s ×132` (2026-08-30T13:05:43Z f516cff4) — a unit-time skew signal, not a per-session burn signal. No threshold mapping from burn rate to steer/die is observable in the named files. | not established: no grounded trigger. A per-session token-burn-rate detector and its threshold is unbuilt; until one exists, burn judgments stay qualitative per the roguelike rule's "correct small step under budget" clause. |

Decision ordering when signals co-occur: `error` outranks `stall`/`loop` (the watchdog checks error first and the
roguelike rule makes any unrecovered error a death trigger); a single stall window defaults to steer, repeated windows
or post-steer repetition default to die+replace; procedural hook availability converts a would-be death into a cheaper
rotation at the turn boundary.

## Not established

- A quantitative budget-burn-rate threshold (no alert class, no per-session burn telemetry in the named files).
- Whether the ×N repetition count that flips steer → die for stall windows generalizes; the ×4 evidence is one pattern,
  not a calibrated constant.
- Automated kill/launch on any signal: the watchdog is log-only by design; no response leg is currently automated.

## Grounding

Verified paths read for this record (2026-08-31):

- `docs/project/roguelike-agentic.md` — the source rubric: death triggers, procedural hook section, "when NOT to
  respawn", the learning-vs-burning judgment, and the 2026-08-26 WebDashboard provenance note.
- `docs/project/reports.md` — filed alert classes read directly: `agent-stall` (alerts + `recovered` progress pairs),
  `loop-signal` ("3x identical crumb", "3 markers in 5m"), `slow-unit` (`dropin:20-workbeat.sh wall=229.4s median=0.2s
  ×132`), `tree-skew` ("dirty and uncommitted >4h ×90", 2026-08-30T04:00:43Z 96bd99de), plus the daily `budget digest`
  progress rows.
- `~/Projects/etc/hngh-automation/jobs/agent-watchdog.sh` — read in full: tunables (`STALL_MIN=10`,
  `LIVE_MIN=180`, `ERROR_GRACE_MIN=2`, `LOOP_N=3`), detection classes `error`/`loop`/`stall`, LOG-ONLY `ingest`
  (handoffs ledger line + report-queue alert + ATTENTION_FLAG touch), live-subagent exemption, fail-open stance.

## Batched landing

This document rides the next certificate ceremony; the orchestrator lands KERNEL docs changes. It is authored
2026-08-31 under the plan-mandated 2026-08-30-* filename. No code was written in this beat; KERNEL src/, tests/,
Makefile, and hngh.asd were untouched.
