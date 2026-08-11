# Wave: M7 — Client-Server Daemon Mode (Emacs-style headless + extensible clients)

> Convention: self-contained working context for one wave. Grounded in source 2026-08-01.

## Context

hngh currently runs as a foreground process with embedded tmux (mission-control) and emacs-daemon plugins. M7 transforms hngh into a **daemon + client architecture**:

- **hngh-daemon**: Headless SBCL process (systemd user service), owns the event loop, scheduler, plugin host, state store, event bus
- **Clients**: Thin CLI (`hngh`), Emacs panel (`hngh-mc.el`), future TUI/dashboard — connect via Unix socket wire protocol
- **Wire protocol**: Length-prefixed S-expressions over Unix sockets (later TCP), minimal framing, session/heartbeat/plugin layers live above

This matches the M7 draft in `.omc/plans/hngh-gbd-dogfood-program.md` and the ADR direction in `hngh/journal/20260801-day-tasks-queue.md` item 8.

## Current State (verified 2026-08-01)

- `src/core/main.lisp` (241 lines): Full init sequence (event-bus → state-store → supervisor → scheduler → threat/resource → 11 plugins → `*running* t`); `stop` reverse; `main` arg parse, start, **blocking loop** `(loop while *running* do (sleep 1))`, `--once` single tick
- `src/plugins/mission-control.lisp`: tmux wrapper, `summon` uses `agent-call`, `mc` script is layout source of truth
- `src/plugins/emacs-daemon.lisp`: daemon lifecycle (start/stop/health), policy-explicit start, daemon outlives hngh
- `src/plugins/ai-orchestrator.lisp`: task queue + driver (M3), `delegate` + `handoff`, transcript persistence
- `src/plugins/sentry.lisp`: procedural safeguards (secret-guard + context-watch), Tier-0
- All plugins follow pattern: `init`/`shutdown`/`running-p`/`status`, registered in `main.lisp` init sequence
- Systemd: `unsloth-studio.service` + `unsloth-warm.service` (M0) keep gemma-4-12b warm at :8888

## Target State

### 1. Daemon Core (`src/core/daemon.lisp` — new)

```lisp
(defvar *daemon-socket-path* "daemon/socket"
  "Unix socket path relative to *hngh-home*.")
(defvar *daemon-server* nil)
(defvar *client-connections* (make-hash-table :test 'equal))

(defun daemon-start (&key (hngh-home *hngh-home*))
  "Start the Unix socket server. Called from main.lisp after plugin init.")
(defun daemon-stop ()
  "Close server socket and all client connections.")
(defun daemon-handle-client (stream)
  "Read length-prefixed S-expr, dispatch, write response.")
(defun daemon-broadcast (event)
  "Send event to all connected clients.")
```

### 2. Wire Protocol (length-prefixed S-expr over Unix socket)

```
[4-byte BE length][S-expression bytes]
```

Message types:
- `:request` — client → daemon (with `:id` for response correlation)
- `:response` — daemon → client (matches `:id`)
- `:event` — daemon → client (async, no `:id`: `task-completed`, `maintenance.state-changed`, `threat.flag`, `hnghbeat`)

Example request:
```lisp
(:request :id 42 :op :submit-task :payload "Reply with exactly: ok" :policy '(:prefer-tool :local-openai-api))
```

Example response:
```lisp
(:response :id 42 :status :ok :result 7)  ; task id 7
```

Example event:
```lisp
(:event :topic :task-completed :payload (:id 7 :status :done))
```

### 3. Client CLI (`src/client/main.lisp` — new, builds `hngh` binary)

```lisp
(defun client-connect (&optional (socket-path (merge-pathnames *daemon-socket-path* *hngh-home*)))
  "Open Unix socket connection to daemon.")
(defun client-request (op payload &key policy)
  "Send request, wait for response with matching :id.")
(defun client-submit-task (task &key policy)
  "Convenience: (client-request :submit-task task :policy policy).")
(defun client-list-tasks (&key status)
  "Convenience: list tasks via daemon.")
(defun client-watch-events (&key (topics nil))
  "Stream events; print to stdout as JSON or S-expr.")
(defun main ()
  "CLI entry: parse subcommands (submit, list, watch, status, stop-daemon).")
```

### 4. Emacs Panel Integration (MC-2 wave 4)

- `emacs/hngh-mc.el`: Add `*hngh-client*` panel (slot 3, right side)
- `hngh-mc-client-connect` — open persistent connection to daemon socket
- `hngh-mc-client-submit-task` — prompt for task, send via connection
- `hngh-mc-client-watch-events` — async process filter, append to `*hngh-events*` buffer
- `hngh-mc-balance-windows` / `hngh-mc-rotate-windows` already handle 5+ panels

### 5. Main.lisp Changes

- After plugin init: `(daemon-start)` (guarded `ignore-errors`)
- Replace blocking loop with daemon-aware loop:
  - If `--client` flag: run CLI subcommand, exit
  - If `--daemon` flag: start daemon, enter blocking loop
  - Default (no flag): start daemon + enter blocking loop (current behavior)
- `--once` still works: single task-driver tick, then stop
- Signal handlers unchanged (call `stop` which calls `daemon-stop`)

### 6. Systemd Integration

- `hngh-daemon.service` (user) — `ExecStart=hngh --daemon`, `Restart=on-failure`
- `hngh-daemon-warm.service` (oneshot) — warm-up call to daemon health endpoint
- Socket activation optional (systemd socket unit) — later wave

## Tasks

1. **Design doc** (this file) — DONE
2. **Daemon core** (`src/core/daemon.lisp`) — Unix socket server, client handling, broadcast
3. **Wire protocol** (`src/core/wire-protocol.lisp`) — encode/decode length-prefixed S-expr, message types
3. **Client CLI** (`src/client/main.lisp`) — `hngh` binary entry, subcommands, connection pooling
4. **Main.lisp integration** — daemon-start after init, flag parsing (`--daemon`, `--client`, `--once`)
5. **Emacs panel** (`emacs/hngh-mc.el`) — `*hngh-client*` panel, submit/watch commands
6. **Systemd units** — `hngh-daemon.service`, `hngh-daemon-warm.service`
6. **Tests** — daemon start/stop, client request/response, event broadcast, emacs panel smoke
7. **Live verification** — systemd start daemon, `hngh submit "task"` → `:done`, emacs panel submit/watch
8. **Record** in `docs/project/work-sessions.md`; `memo note "hngh: M7 client-server daemon live"`

## Verification (wave complete when)

- `make test` green incl. new daemon/client tests
- `systemctl --user start hngh-daemon` → daemon healthy, socket at `~/.hngh/daemon/socket`
- `hngh submit "Reply with exactly: ok"` → task id returned, queue shows `:done` with "ok"
- `hngh watch` streams `:task-completed` events
- `mc` opens 6 panes (svc-dash | daemon | status | events | agent | **hngh-client**), emacs panel submits task → appears in daemon queue
- `systemctl --user stop hngh-daemon` → clean shutdown, socket closed

## Anti-patterns

- **No HTTP/REST** — Unix sockets are simpler, faster, no TLS/serialization overhead; TCP later if remote clients needed
- **No client-side state** — clients are thin; all state (queue, plugins, config) lives in daemon
- **Don't couple wire protocol to plugin internals** — protocol is stable contract; plugins evolve independently
- **Don't block daemon on client I/O** — client handling is async (one thread per connection or I/O multiplexing)
- **Don't hardcode socket path** — configurable via `*daemon-socket-path*`, default `daemon/socket` under `*hngh-home*`