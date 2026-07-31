# Wave: M6.1 — mission control (tiled tmux observability + agent summoning)

> Convention: self-contained working context for one wave. Grounded 2026-07-31 in the running stack (svc-dash, hngh daemon, OptMem, agent-call, gbd).

## Context

Work now spans many live parts: the hngh daemon + queue, svc-dash, unsloth, llmtrim, hermes/opencode workers, subagents. Watching them means juggling windows. M6.1 builds **mission control**: one command (`mc`) opens a tiled tmux session with the dashboard, daemon, status watcher, event journal, and free agent panes — scrollable, auto-tiling, at-startup or on-demand. hngh owns the feature (plugin wraps the launcher); gbd tracks the config; agent-call summons siblings into panes.

## Current state (exact)

- tmux available; `hngh-m2` worker pattern proven (tmux new-session -d, capture-pane).
- svc-dash runs via `uv run --project ~/Projects/etc/svc-dash python -m svc_dash.app`; `hngh-status` at `~/.local/bin/hngh-status` (queue table + events tail + process check).
- hngh daemon: `make run` in `~/Projects/etc/hngh` (long-lived loop; logs to stdout; event journal at `~/.hngh/journal/events/<date>.lisp`; queue at `~/.hngh/tasks/queue.lisp`).
- agent-call summons hermes/opencode headlessly with memo logging.
- hngh plugin contract: file in `src/plugins/`, defpackage in `src/packages.lisp`, component in `hngh.asd`, init/shutdown calls in `src/core/main.lisp` start/stop/rollback.

## Target state

1. **`~/.local/bin/mc`** (operational core): `mc` = attach-or-start; `mc start|stop|status`; `mc add "<cmd>"` (new tiled pane running cmd + `exec bash`). Panes: svc-dash | hngh daemon (`make run`) | `watch -n2 hngh-status` | event-journal tail | free. Layout `tiled`, re-tile after each add. Session name overridable via `MC_SESSION` (tests use `hngh-mc-test`).
2. **`src/plugins/mission-control.lisp`**: init/shutdown/running-p/status + `start-session`, `stop-session`, `add-pane (command)`, `summon (target task &key model)` (wraps agent-call in a pane), `session-alive-p`. Thin wrapper: calls `mc` via run-program (one source of truth).
3. Registration: defpackage, hngh.asd component, main.lisp init (last, before `*running* t`) + shutdown (stop + rollback).
4. `tests/unit/test-mission-control.lisp` + asd entry: live tmux test on `hngh-mc-test` — start ⇒ 4+ panes; add ⇒ +1; stop ⇒ gone. Guard: skip if tmux missing.
5. Autostart: `~/.config/autostart/hngh-mc.desktop` (alacritty -e mc) — at-startup option; delete to opt out.
6. gbd: add `mc` + `hngh-status` to agent-configs tracks; commit.

## Tasks

1. mc script + live smoke (start/status/add/stop on the real session — it becomes the running session).
2. Plugin + registration (3 files).
3. Tests + `make test` green.
4. Submit the wave-5 implementation-draft task (app.py inlined) — verify it processes in the mc daemon pane.
5. Autostart entry + gbd track/commit.
6. Record: work-sessions, OptMem, plan doc.

## Verification (wave is complete when)

`mc` opens the tiled session with all panes live; an `mc add 'agent-call …'` pane appears tiled; the queued task reaches `:done` while the daemon pane shows the tick; `make test` green incl. mission-control tests.

## Anti-patterns

- **No second layout engine** — tmux `tiled` does the tiling; don't hand-place panes.
- **Don't split logic between mc and the plugin** — mc is the only layout/truth; the plugin delegates.
- **No pane spam** — free panes are created by `mc add`/`summon` only, never on a timer.
- **Don't autostart-hidden** — the desktop entry opens a visible window; silent background watchers belong to systemd units, not XDG autostart.
- **Don't track secrets in gbd** — mc/hngh-status contain no keys; keep it that way.
