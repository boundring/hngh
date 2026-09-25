# P4 — single supervision plane (three-state machine)

Date: 2026-09-25. Plan: refoundation P4 (supervision). Committed with
P4a root-cause rename in one slice.

## Root cause fixed (P4a)

`automation/lib/launch-session.sh:490` classified every clean `rc=0`
run as `LAUNCH_DISPOSITION="cancelled"` — a header comment admitted it
was "existing ledger vocabulary". Every healthy session was recorded as
a cancellation, and `classify_cause` on a healthy log tail returns the
no-match class, so the ledger filled with `cancelled cause=unknown`
rows for sessions that did not fail. Fixes:

- rc=0 now records `complete`; rc!=0 stays `dead`.
- `automation/lib/causes.sh`: the no-match class is renamed
  `unknown` -> `unclassified` (both printf sites). `cause=unknown` is
  banned on transitions; a dying session whose log matches no class is
  named `unclassified` and emits one deduped report row
  (`cause-unclassified:<slug>`, window 7d) so the gap is visible.
- Tests repinned: `tests/test-causes.py` (6 assertions),
  `tests/test-ocgo-launch.py:682` (disposition pin — found by the fold
  agent's full-gate run, initially mislabeled a phantom).

## Single supervision plane (P4b/c/d)

`automation/jobs/agent-supervision.py` is now the only supervision
machine. Retired: `jobs/agent-watchdog.sh`, `jobs/beat-watchdog.py`,
`cadence/subhour/46-beat-watchdog.sh`, `tests/test-beat-watchdog.py`,
the Makefile `sweep` target + `.PHONY` entry, and
`oversight-tick.sh`'s `probe_agent_watchdog`. `jobs/sweep-artifacts.sh`
stays — live caller `jobs/ping-hourly.sh:127` (only the Makefile
target died).

Ported detections (from agent-watchdog scan, now in
`scan_transcript`): identical-tool-loop (trailing N identical tool
calls, name+args) and hard-error-without-recovery (errish toolResult
older than the grace window). Beat-watchdog checks folded as
`overnight_lead_checks` on the virtual session `overnight-lead`:
launch-stall (>= beat-stall-n trailing failed overnight-done tokens),
same-cause deaths (>= blocker-escalate-n consecutive dead rows, one
class -> `supervision:overnight-lead:same-cause:<class>` + a
`state/beat-blockers.tsv` row in the existing shape), beat silence
(overnight-done older than beat-stall-silence-hours while cadence
crumbs arrive; rewritten TZ-proof via `_iso_ts`).

Three states per tracked session, tick = one 300s pass, evidence =
transcript growth | spine crumb | commit/file-write:

- `active` — evidence age <= 2 ticks.
- `slow-valid` — evidence present, tool calls flat > 20m: one progress
  row `supervision:<sid>:slow-valid` (re-queue at cheaper tier), never
  killed, never steered.
- `stalled` — no evidence 2 consecutive ticks: first miss steers once
  (handoff row `stalled: steer:` + alert row); second consecutive miss
  dies — bridge runs keep the replace path (`hngh close-run dead`,
  record rotation, `--run-start` re-provision) with the cause from
  `classify_cause`; omp transcripts stay advisory (handoff + alert,
  never killed). `unclassified` passes through as the named cause.

Alert path is one shape: `supervision:<session>:<state>`, window 7d,
kind alert for stalled/die, progress for slow-valid/recovered flaps.

`scripts/router-tick.py:144` NORMAL_SHAPES now matches `:stalled` so
supervision stall rows keep the one-stepper routing. Cadence param rows
re-cited to agent-supervision.py (values unchanged; two dead
watchdog-stall-min/watchdog-live-min rows deleted).

## Verification

- `tests/test-agent-supervision.py` 9/9 (was 2): transition matrix —
  active, slow-valid (no kill), steer-once-then-die, bridge replace via
  hermetic stubs, loop + error detections, overnight-lead silence.
  Hermetic via SUPERVISION_* env seams.
- `tests/test-causes.py` 23/23, `tests/test-ocgo-launch.py` 35/35,
  selfchecks (`--selfcheck`, `--selfcheck-replace`) OK.
- `automation make test` green; root `make test` green.
- Remnant grep: `agent-watchdog|beat-watchdog` only in historical state
  rows, dated CHANGELOG entries, and retirement docstrings. One live
  ref fixed en route: `tests/test-cadence-collapse.sh` old-tier mount
  inventory no longer expects `46-beat-watchdog`.

## Delegation note

The fold was delegated with a decision-complete spec. First delivery
claimed success with nothing on disk (interim report; agent was still
running). After a state-correction message the fold landed in the main
tree and passed. Lesson: on subagent-reported success for file edits,
verify with `git status` before gating — reports can arrive before the
work.
