# 2026-09-15 — Swarm coordination lessons (meta-review wave 1)

Source: the lessons meta-review graph (forensics-catalog,
resolution-audit + six child audits, hngh-lesson-extraction,
jcode-upstream-candidates). This record consolidates the completed
artifacts; the lessons-synthesis node appends machine rows when its
final blocker (jcode-upstream-candidates) closes.

## Incident catalog (from forensics + resolution audits)

| # | Incident | Cause class | How resolved | Durability |
|---|---|---|---|---|
| 1 | Visible-spawn workers flash-died (self-dev TUI needs PTY; spawn path wrapped it non-interactively) | infrastructure | tmux spawn router landed; real fix (server restart to load hook) operator-pending | WORKAROUND/FRAGILE until restart |
| 2 | CI failure streak (link guard vs gitignored host paths) | test-design | two-pass root-cause fix (check-ignore per token) | permanent; needs a regression pin test on a fresh-clone simulation |
| 3 | Push divergence (two same-host sessions racing origin) | coordination | force-with-lease to the linear superset + routed plan closure | correct recovery; prevention is documentation-only (no pre-push guard) |
| 4 | Lessons-loop set -u unbound variable | test-isolation | caught by fixture tests pre-merge; env scrub added | permanent (fixture gate) |
| 5 | complete_node ownership mismatches (workers' closures rejected) | coordination-plane | assign_task to artifact holders, case by case | FRAGILE — workaround; NotOwner errors omit the owner id (jcode dag/mod.rs:488-490) |
| 6 | run_plan driver cancel/restart killing spawned workers' process groups | infrastructure (jcode) | restart driver; workers re-dispatch | FRAGILE — no jcode-scoped stall/GC detector for dead placeholder workers |
| 7 | Zai concurrent-request rate limit flash-failing ~20-40 spawned workers | operator-env (quota/concurrency) | swarm_max_concurrent_agents 32→6; light fan-out | conditional (config), verified by failure-rate drop |
| 8 | Kimi window caps blown mid-graph | operator-env (quota) | swarm_model ladder (openrouter contributor, then back to zai) | conditional (config ladder in cadence-params) |

## New coordination-plane cause classes proposed

hngh's bestiary covers agent-execution failures. Today's failures are
mostly *coordination-plane* — the swarm machinery itself, not the
agents. Proposed classes for lib/causes.sh vocabulary:

- `coord-ownership`: node/task ownership mismatch between planner and
  worker sessions (detection: NotOwner rejection; fix: assign_task
  transfer).
- `coord-driver-death`: driver process-group termination orphaning
  assignments (detection: roster entries stuck queued with no session
  file; fix: driver restart + re-dispatch).
- `env-quota`: provider window/concurrency caps exhausting under
  fan-out (detection: provider error signatures; fix: concurrency cap +
  model ladder).

## Faster-detection signals proposed

1. Roster watchdog: alert when a node stays `queued` with a dead
   worker session for >N minutes (would have cut incident 6 detection
   from ~40 minutes to one tick).
2. Pre-flight concurrency self-check: a driver that plans to spawn N
   workers against a rate-limited endpoint should read the endpoint's
   known concurrency (zai) and clamp N (would have prevented incident
   7 entirely).
3. Ownership probe on rejection: NotOwner errors should name the
   current owner (upstream jcode candidate, verified against
   dag/mod.rs:488-490).

## Jcode upstream candidates (per OSS contribution policy)

All four verified against ~/src/jcode source:

1. run_plan driver cancel terminates spawned workers' process groups
   (candidates for detached spawn or explicit graceful stop).
2. self-dev TUI PTY failure message could suggest configuring
   `[terminal].spawn_hook` when stdin is not a TTY.
3. NotOwner complete_node rejections could include the owning session
   id.
4. Dead placeholder workers (driver died pre-dispatch) are never
   garbage-collected from the roster.

Each is a small, diagnosable behavior gap; file after independent
reproduction on a current jcode build.

## Wiring note

The lessons-synthesis graph node appends rows to
automation/state/ocgo-agent-lessons.md through the standard append
path when it unblocks. This record is the human-readable corpus;
the machine rows ride the normal lessons format.
