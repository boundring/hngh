# Session Lifecycle & Window Management — M2 Plan

**Date**: 2026-08-02
**Author**: Designer (GLM-5.2)
**Status**: Plan — for owner/PM approval
**Milestone**: M2 (The Companion) — bridges into M3 (The Network)

## Goal

Hngh can detect external config changes (Hermes config.yaml, .env), gracefully
restart dependent agent sessions, and restore tmux window layout including pane
sizes, positions, and working directories. Builds on existing `mc` script,
mission-control plugin, event bus, and scheduler.

## Current context

**What exists:**
- `mc` script: 4 fixed panes (svc-dash, hngh daemon, status, events). `mc refresh` respawns dead panes. `mc add` splits new panes with tiled layout.
- mission-control.lisp: `start-session`, `stop-session`, `add-pane`, `summon`, declarative squads with tmux lifecycle, squad state persistence (write-squad-state, read-squad-state).
- Scheduler: timer-based tick loop, publishes events on the bus.
- Event bus: pub/sub with wildcard topics, event journaling.
- State store: file-tree read/write, SQLite locks, journal append, snapshots.
- `config.changed` event: system-config emits it, backup-manager listens. Nothing reloads Hermes config.
- Plugin hot-reload: plugin-host supports `:reload` for individual plugins.
- Agent platoons design (agent-platoons.md): declarative squad specs with preflight gates, role layouts, wake templates. Design complete, implementation pending (M9).
- Phase 2 complete: M7 wire protocol handlers for claim/release/complete/block/fail/ready. Scheduler lease expiry. 1120/1120 tests green.

**What's missing:**
1. Config file watcher (inotify on config.yaml + .env)
2. Graceful restart protocol (stop → apply → restart → restore)
3. Pane state persistence (save/restore indices, sizes, cwd, commands)
4. Layout restore on restart (recreate panes with saved geometry, not just re-tile)
5. Cascading session windows (parent/child relationships, multi-window)
6. Config diff and targeted reload (apply only what changed)

## Proposed approach

Three waves, each independently shippable. Each wave has fixture-based tests
first, then implementation. Files named explicitly.

### Wave 1: Pane State Persistence & Layout Restore

Save and restore tmux pane geometry. The `mc` script becomes stateful: it
saves pane layout on `mc stop` and restores it on `mc start`.

**Files:**
- `~/.local/bin/mc` — add `save-layout` and `restore-layout` subcommands
- `src/plugins/mission-control.lisp` — add `save-session-layout` and `restore-session-layout` functions
- `tests/unit/test-mission-control.lisp` — fixture tests for layout save/restore

**Design:**
- `mc save-layout`: `tmux list-panes -t $SESSION -F '#{pane_index} #{pane_width}x#{pane_height} #{pane_current_path} #{pane_current_command}'` → write to `~/.hngh/state/mc-layout.lisp`
- `mc restore-layout`: read saved layout, recreate panes with `tmux split-window` using `-h`/`-v` and explicit sizes via `tmux resize-pane`
- Layout format: plist `(:panes ((:index 0 :width 80 :height 40 :cwd "/path" :cmd "svc-dash") ...))`
- `mc stop` auto-saves layout; `mc start` checks for saved layout and restores if present
- Fallback: no saved layout → current tiled behavior

**Tests (fixture-based):**
1. Save layout produces valid plist with correct pane count
2. Restore layout recreates correct pane count
3. Pane sizes match saved values within tolerance
4. Missing layout file → tiled fallback (no error)
5. Malformed layout file → tiled fallback + log warning
6. Save → stop → restore roundtrip preserves cwd

### Wave 2: Config Watcher & Targeted Reload

Watch Hermes config files for changes. Emit `hermes.config.changed` event. A
new `config-watcher` plugin listens and triggers targeted reloads.

**Files:**
- `src/plugins/config-watcher.lisp` — new plugin: inotify on config.yaml + .env
- `src/core/event-bus.lisp` — no changes (already supports pub/sub)
- `src/plugins/mission-control.lisp` — add `handle-config-changed` to restart affected sessions
- `tests/unit/test-config-watcher.lisp` — fixture tests

**Design:**
- inotify via `sb-posix:inotify-add-watch` (or shell out to `inotifywait`)
- Watch: `~/.hermes/config.yaml`, `~/.hermes/.env`, `~/.hermes/config.yaml` in profiles
- On change: emit `hermes.config.changed` with `:file`, `:section`, `:before`, `:after`
- Config diff: parse YAML before and after, compare key paths, emit only changed sections
- Targeted reload: if `auxiliary.goal_judge` changed → signal goal_judge to reinitialize; if `providers` changed → signal model-runtime; if `delegation` changed → signal ai-orchestrator
- If config is structurally invalid (YAML parse fails) → emit warning, do NOT apply (fail closed)

**Tests:**
1. File change triggers event with correct `:file` path
2. Config diff identifies changed section correctly
3. Invalid YAML → warning emitted, no reload
4. Targeted reload calls correct handler for changed section
5. No-op when file content unchanged (mtime change only)
6. Multiple rapid changes debounce to single event

### Wave 3: Cascading Session Windows & Auto-Relaunch

Orchestrate graceful restart of agent sessions with pane restoration. Mission
control becomes the session lifecycle manager.

**Files:**
- `src/plugins/mission-control.lisp` — add `restart-session`, `cascade-restart`
- `~/.local/bin/mc` — add `mc restart` subcommand
- `tests/unit/test-mission-control.lisp` — integration tests for restart cycle

**Design:**
- `mc restart`: save layout → stop session → (config is reloaded by caller on next start) → start session → restore layout → verify all panes alive
- `restart-session` (Lisp): save state → stop-session → start-session → restore-session-layout → emit `session.restarted` event
- `cascade-restart`: restart parent session, then restart all child squad sessions in dependency order (parents before children)
- Session tree: maintain parent/child relationships in `~/.hngh/state/session-tree.lisp`
- Window placement: each session gets its own tmux window (not just panes in one window); windows are named `mc-main`, `squad-duo-review`, etc.
- `mc status` shows session tree with pane health

**Tests:**
1. Restart cycle preserves pane count and sizes
2. Restart with no saved layout → tiled fallback
3. Cascade restart respects dependency order
4. Child session restart doesn't affect parent
5. Dead pane detection after restart triggers `mc refresh` automatically
6. Session tree persists across daemon restarts

## Files likely to change (summary)

| File | Wave | Change |
|------|------|--------|
| `~/.local/bin/mc` | 1, 3 | save-layout, restore-layout, restart subcommands |
| `src/plugins/mission-control.lisp` | 1, 2, 3 | layout persistence, config-changed handler, restart logic |
| `src/plugins/config-watcher.lisp` | 2 | new plugin |
| `tests/unit/test-mission-control.lisp` | 1, 3 | layout + restart tests |
| `tests/unit/test-config-watcher.lisp` | 2 | new test file |
| `src/packages.lisp` | 2 | export config-watcher package |
| `src/plugins/packages.lisp` | 2 | add config-watcher to plugin list |
| `hngh.asd` | 2 | add config-watcher source file |
| `docs/project/roadmap.md` | all | add M2 milestones for session lifecycle |

## Risks and tradeoffs

1. **inotify portability**: `sb-posix:inotify-add-watch` is Linux-only. Acceptable — Hngh targets CachyOS/Arch. Fallback: poll mtime every 5s if inotify unavailable.

2. **YAML parsing in Lisp**: Hngh core is CL. Parsing YAML requires a CL YAML library (e.g., `cl-yaml`). Alternative: shell out to `python3 -c 'import yaml...'` for diff. The latter is simpler but adds a Python dependency to core. Recommendation: shell out — Python is already a hard dep for svc-dash and the system daemon.

3. **tmux geometry restore is approximate**: `tmux resize-pane` works in rows/columns, not pixels. Pane sizes will be within 1-2 rows of saved values. Acceptable for terminal layouts.

4. **Config reload race condition**: between stop and start, a config change could arrive. Mitigation: debounce config events (300ms) and check mtime before applying.

5. **Session tree complexity**: parent/child relationships add state. Keep it simple: flat list with optional `:parent` field. No deep trees.

## Open questions

1. Should config-watcher also watch profile config (`~/.hermes/profiles/<name>/config.yaml`)? Or only the active profile?
2. Should `mc restart` be automatic (triggered by config-watcher) or manual? Recommendation: manual by default, with an opt-in `auto-restart-on-config-change` setting.
3. Should the session tree survive daemon crashes? If yes, write to state-store (atomic temp+rename). Recommendation: yes.

## Verification

Each wave ends with:
- `make test` green (no regressions)
- Manual smoke test: `mc start` → `mc stop` → `mc start` with restored layout
- Event journal shows `session.restarted` / `config.changed` events
- Wave 2: modify config.yaml while daemon running, verify event fires
- Wave 3: `mc restart` preserves all panes with correct sizes and cwds
