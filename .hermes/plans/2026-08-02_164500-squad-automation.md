# Squad Automation Plan — Spin-Up, Management, and Progressive Self-Direction

**Date**: 2026-08-02
**Author**: Designer (GLM-5.2)
**Status**: Plan — for owner approval

## Goal

Eliminate manual window management, prompt cultivation, and copy-paste
coordination for the 6-agent squad. Three layers of automation, each
building on the last:

1. **Scripted spin-up** (done: `squad-up`) — launches seats in Konsole windows
2. **Session management** — role-ack, breadcrumb injection, health monitoring
3. **Progressive autonomy** — Hngh manages the squad itself as an extension

## Current context

**What exists:**
- `squad-up` script (`~/.local/bin/squad-up`): launches 6 seats in cascading
  Konsole windows. Config in `~/.hngh-night/squad-seats.conf`. Supports
  `--list`, `--status`, `--stop`, and selective seat launch.
- `mc` script (`~/.local/bin/mc`): tmux session with 4 fixed panes.
- OptMem (`~/.optmem/memo`): shared memory for inter-agent communication.
- Breadcrumbs (`~/.hngh-night/artifacts/SESSION-RESET-BREADCRUMBS.md`):
  manual session restart state.
- M2 plan: session lifecycle & window management (tasks 81-83).

**What's still manual:**
- Moving and resizing windows
- Typing/writing prompts on-the-fly
- Copy-pasting context between agents
- Checking if agents are alive, responsive, or stuck
- Restarting crashed or rate-limited sessions
- Switching models when a provider fails or quota exhausts
- Fanning out workers for parallel tasks

## Proposed approach — three layers

### Layer 1: Enhanced squad-up (script improvements)

Make the existing script smarter without requiring Hngh.

**Files:**
- `~/.local/bin/squad-up` — add features below
- `~/.hngh-night/squad-seats.conf` — already done (benchmark-aware routing)

**New features:**

1. **Auto role-ack + OptMem wake**: Each window runs `python3 ~/.optmem/memo wake`
   before launching the CLI. Agent sees its memory immediately on startup.

2. **Breadcrumb injection**: Read `SESSION-RESET-BREADCRUMBS.md` and pipe key
   sections into each agent's first prompt. Not the whole file — just the
   "After reset" checklist and pending tasks for that seat.

3. **Health check loop** (`squad-up --watch`): Background process that polls
   every 30s. If a seat's process dies, auto-relaunch with the same model.
   Logs to `~/.hngh-night/squad-health.log`.

4. **Model failover** (`squad-up --failover`): If primary model returns 429/403
   more than 3 times in 5 minutes, switch that seat to its fallback model.
   Requires a small state file tracking current model per seat.

5. **Fanout** (`squad-up --fanout worker 3`): Launch N copies of a seat with
   incrementing window offsets. Each gets a unique prompt suffix
   (`worker-1`, `worker-2`, `worker-3`) so OptMem notes are distinguishable.

6. **Layout presets**: Named window arrangements beyond the default cascade.
   `--layout cascade` (default), `--layout grid`, `--layout row`, `--layout stack`.
   Save/restore with `--layout-save <name>` and `--layout-restore <name>`.

**Tests:**
- `squad-up --list` shows correct seats
- `squad-up --fanout worker 2` launches 2 worker windows with unique prompts
- `squad-up --watch` detects and relaunches a killed process
- `squad-up --failover` switches model after 3 consecutive errors
- `squad-up --layout-save` / `--layout-restore` roundtrip preserves positions

### Layer 2: Session management daemon (squad-mgr)

A lightweight background service that manages the squad lifecycle.

**Files:**
- `~/.local/bin/squad-mgr` — management daemon (bash + python)
- `~/.hngh-night/squad-state.json` — persistent state (current models, health,
  last-seen, window positions)

**Features:**

1. **Heartbeat monitoring**: Each agent writes a heartbeat to
   `~/.hngh-night/state/<seat>.heartbeat` every N turns. `squad-mgr` checks
   staleness. No heartbeat in 5 minutes → flagged stale.

2. **Automatic restart**: If a seat is stale or dead, `squad-mgr` relaunches
   it with the same model (or fallback if the model is unhealthy). Injects
   the latest breadcrumbs and OptMem wake into the new session.

3. **Model health tracking**: Tracks 429/403/503 per model per seat. If a
   model is consistently failing, promotes the fallback to primary and
   logs the switch. Resets after a cooldown period.

4. **Squad status dashboard** (`squad-mgr status`): One-line per seat:
   `pm: RUNNING  kimi-k2.6  3min ago  0 errors | designer: RUNNING  glm-5.2  1min ago  0 errors`

5. **Task routing**: Reads `~/.hngh-night/tasks/` and posts a note to OptMem
   assigning unclaimed tasks to idle seats. Respects dependencies (81 before 83).

6. **Coordinated shutdown** (`squad-mgr drain`): Signals all seats to finish
   current work, write breadcrumbs, then exit gracefully. Useful for
   config changes that require full restart.

### Layer 3: Hngh integration (M2/M3)

Absorb squad-mgr into Hngh as a first-class plugin.

**Files:**
- `src/plugins/squad-manager.lisp` — new plugin
- `src/core/daemon.lisp` — wire `squad-*` wire protocol operations
- `tests/unit/test-squad-manager.lisp` — tests

**Features:**

1. **Wire protocol**: `:squad-up`, `:squad-down`, `:squad-status`,
   `:squad-failover`, `:squad-fanout` operations through the M7 daemon.

2. **Event bus integration**: `squad.seat.launched`, `squad.seat.died`,
   `squad.seat.failover`, `squad.task.assigned` events. Other plugins
   (mission-control, hnghbeats) can subscribe.

3. **Scheduler integration**: Periodic health checks via the existing scheduler
   tick. No separate daemon needed — Hngh's scheduler already runs ticks.

4. **State store**: Session tree, model health, and per-seat state persisted
   in `~/.hngh/state/squad/` with atomic writes.

5. **Config watcher integration** (Wave 2 of M2 plan): When Hermes config
   changes, `squad-manager` evaluates whether seats need restart and
   coordinates a `drain → config reload → relaunch` cycle.

6. **Benchmark gate**: Continuously benchmarks local models against a
   minimum capability test suite. Models that fail the gate are removed
   from the fallback chain until they pass again.

## Implementation order

| Step | What | Files | Depends on |
|------|------|-------|------------|
| 1 | squad-up enhancements (role-ack, fanout, health) | `~/.local/bin/squad-up` | nothing |
| 2 | squad-mgr daemon (heartbeat, restart, status) | `~/.local/bin/squad-mgr` | step 1 |
| 3 | Layout presets + save/restore | `~/.local/bin/squad-up` | step 1 |
| 4 | M2 Wave 1 (pane persistence) | `mc`, mission-control.lisp | nothing (parallel) |
| 5 | M2 Wave 2 (config watcher) | config-watcher.lisp | nothing (parallel) |
| 6 | M2 Wave 3 (cascading restart) | `mc`, mission-control.lisp | step 4 |
| 7 | Hngh squad-manager plugin | squad-manager.lisp | steps 2+5+6 |
| 8 | Benchmark gate for local models | squad-manager.lisp | step 7 |

Steps 1-3 are scripted (bash, no Hngh dependency). Steps 4-6 are the M2 plan.
Step 7 absorbs the scripts into Hngh. Step 8 adds the local-model benchmarking.

## Risks

1. **Window management via script is fragile**: Konsole geometry via
   `--geometry` is approximate. KDE window rules may override. Mitigation:
   Layer 3 uses tmux (via `mc`) which is deterministic, not Konsole.

2. **Model failover requires error detection**: We need to parse agent logs
   or track API call results. Mitigation: Layer 2 uses heartbeat files
   (agents self-report), Layer 3 uses event bus.

3. **Fanout with free models hits rate limits**: OpenRouter free tier is
   1000/day. Multiple workers on free models will exhaust it fast.
   Mitigation: Layer 2 tracks quota usage and falls back to local models
   when free tier is exhausted.

4. **Benchmark gate is subjective**: "Minimum capability" is hard to define.
   Mitigation: Start with a simple test: can the model follow a structured
   brief and produce valid output? Expand later.

## Open questions

1. Should `squad-mgr` run as a systemd user service or a background tmux pane?
   Recommendation: systemd user service (`~/.config/systemd/user/squad-mgr.service`)
   — survives logout, integrates with existing daemon lifecycle.

2. Should fanout workers share the same OptMem namespace or get unique ones?
   Recommendation: same namespace with seat-suffixed names (`worker-1`, `worker-2`).

3. How aggressive should auto-restart be? Kill stuck sessions or just warn?
   Recommendation: warn first (log + OptMem note), restart after 2 consecutive
   stale checks (10 min total).

## Verification

- Step 1: `squad-up` launches all seats, each with OptMem wake + breadcrumbs
- Step 2: Kill a seat process, verify `squad-mgr` restarts it within 5 min
- Step 3: `squad-up --layout-save custom && squad-up --stop && squad-up --layout-restore custom`
- Step 7: `hngh squad status` through wire protocol shows same info as `squad-mgr status`
- Step 8: Local model that fails benchmark gate is excluded from fallback chain
