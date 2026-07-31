# Wave: M3 — event loop (task driver on the scheduler)

> Convention: self-contained working context for one wave (see gbd JOURNAL.md). One agent, one wave. Grounded in source 2026-07-31.

## Context

hngh starts every core component and plugin cleanly, then immediately exits: `src/core/main.lisp` L228-230 is the stub ("No event loop yet — start and stop immediately"). With M2 done, the Tool Hub can run $0 local inference via `:local-openai-api` (unsloth :8888). M3 closes the loop: tasks enter a persistent queue, a scheduler-driven driver delegates them (default: free local tool), results are recorded. This is the keystone for autonomous/dogfood loops — NOT full autonomy: single-driver, serial execution, minimal verify.

## Current state (exact, verified 2026-07-31)

- `src/core/main.lisp` (241 lines): `start` L79-153 (init sequence: event-bus → state-store → supervisor → scheduler → threat/resource → 11 plugins → `*running* t`); `stop` L155-195 (reverse); `main` L197-231 (arg parse, start, **stub L228-230**, stop, quit). Signal handlers L60-77 already call `stop` on SIGTERM/SIGINT.
- `src/core/scheduler.lisp`: `schedule (name spec action &key source)` L80 — spec `(:interval N)` / `(:at t)` / `(:delayed s)`; action `(:event topic payload)` or `(:function fn)`; returns id. Errors if scheduler not initialized (register AFTER scheduler init).
- `src/core/state-store.lisp`: `read-state`/`write-state` (relative-path, value) L62/L81, `state-exists-p` L115 — locked s-expression persistence under `~/.hngh/state/`.
- `src/core/event-bus.lisp`: `event`/`subscription` structs, `topic-match-p`; publish wrapper pattern at `ai-tool-hub.lisp` L97 (`publish-event (topic payload &key source)`). CONFIRM: exact core publish fn name before using (likely `hngh.core.event-bus:publish`).
- `src/plugins/ai-orchestrator.lisp`: `delegate (task &key (preferences nil) (context :auto))` L379; `handoff` L541; `ensure-policy` L153 / `policy-from-plist` L143 / `default-policy` L122 (CONFIRM accepted plist keys); agent registry + transcript persistence exist. `delegate` returns an agent-info whose transcript holds the invocation outcome (see `invoke-agent` L421-445 reading `invocation-info-{status,result,error,cost}`).
- Tool Hub: `select-tool` honors `:prefer-tool` when available (L367-370) — deterministic $0 routing via `(:prefer-tool :local-openai-api)`.
- `~/.hngh/state/` exists (init-state-tree creates it).

## Target state

All changes inside `ai-orchestrator.lisp` (queue belongs to orchestration; separate file later if it grows) + the two-line main.lisp change.

1. **Queue model** (top of orchestrator additions):
```lisp
(defvar *task-queue-path* "tasks/queue.lisp")
(defvar *task-queue-lock* (bt:make-lock "hngh-task-queue"))
(defvar *next-task-id* 0)
;; task plist: (:id n :task string :status :queued|:running|:done|:failed
;;              :policy plist :result string-or-nil :error string-or-nil
;;              :submitted-at ut :finished-at ut-or-nil)
```
2. **Public API**:
```lisp
(defun submit-task (task &key (policy '(:prefer-tool :local-openai-api)))
  "Enqueue TASK (string). Returns task id. Persists queue."
  ...)
(defun list-tasks (&key status) ...)          ; read queue, optional status filter
(defun task-driver-tick ()                     ; one driver cycle
  "Pop oldest :queued task, mark :running, delegate with its policy,
   record :done/:failed + result/error, persist, publish event."
  ...)
(defun start-task-driver (&key (tick-seconds 5))
  "Register (:interval tick-seconds) (:function #'task-driver-tick) on the scheduler; store schedule id."
  ...)
(defun stop-task-driver () ...)                ; cancel schedule id
```
`task-driver-tick` semantics: `(hngh.core.state-store:write-state *task-queue-path* queue)` under `*task-queue-lock*` after each mutation; delegate call OUTSIDE the lock (long-running); on success `(eq (invocation-info-status ...) :done)` or non-empty result ⇒ `:done`, else `:failed` with error string; publish `(:event :task-completed (list :id id :status status))` (CONFIRM publish fn name; follow tool-hub wrapper pattern).
3. **main.lisp** (3 edits):
   - After `ai-orchestrator:init` (L127) add: `(hngh.plugins.ai-orchestrator:start-task-driver)` — guarded `(ignore-errors ...)` so a scheduler hiccup can't abort startup.
   - Replace stub L228-230 with a blocking wait: `(loop while *running* do (sleep 1))` then fall through (stop is called by signal handlers; on return, `(stop)` then quit as today).
   - Add `--once` flag in `main`'s cond: after start, call `task-driver-tick` once, then stop+quit (headless single-cycle for tests/CI).
4. **Tests** (`tests/unit/test-ai-orchestrator.lisp` or new `test-task-driver.lisp`): submit → tick with a stubbed delegate (redefine/flet around delegate to avoid network) ⇒ queue transitions :queued→:done, persisted state readable, failed-path sets :failed. CONFIRM test setup helpers used by existing orchestrator tests (`ath-setup`-equivalent; check tests/unit/test-ai-orchestrator.lisp for fixtures).

## Tasks

1. Read `ensure-policy`/`policy-from-plist` (L143-177) — confirm policy plist keys; adjust default if the struct uses different names.
2. Implement items 1-2 in ai-orchestrator.lisp (after `handoff`, ~L600 region end is fine).
3. main.lisp edits (item 3).
4. Tests (item 4): `make test` stays green + new driver tests pass.
5. Live verification (sbcl non-interactive, pattern from M2):
   - init core+plugins, `(submit-task "Reply with exactly: ok")`, `(task-driver-tick)` ⇒ task :done, result contains "ok", cost 0.0, queue file persisted under `~/.hngh/state/tasks/queue.lisp`.
   - `sbcl ... --eval "(hngh:main)" -- --once`-style run (or `make run -- --once` per Makefile) ⇒ starts, one tick, clean shutdown.
6. Record in `docs/project/work-sessions.md`; `memo note "hngh: M3 event loop done — task queue+driver live (local $0)"`.

## Verification (wave is complete when)

All of: `make test` green incl. new driver tests; live tick processes a real task to `:done` via `:local-openai-api` with result persisted; `--once` runs and exits 0; SIGTERM during a long delegate doesn't corrupt the queue (state file parses after restart).

## Anti-patterns

- **No hand-rolled driver thread** — the scheduler already provides interval firing; a second loop thread is a shutdown/locking hazard.
- **Don't hold the queue lock during `delegate`** — blocks submitters for the whole inference.
- **Don't change `delegate`/`select-tool` semantics** — the driver is a consumer, not a modification.
- **Don't default to paid tools** — default policy MUST be `(:prefer-tool :local-openai-api)`; anything else can silently spend money.
- **Don't swallow delegate errors** — capture into the task's `:error` and mark `:failed`; silent drops kill resumability.
- **Don't touch the stub replacement with extra features** (no dashboard wiring, no parallel workers, no retries) — serial, minimal, correct. Later waves: retries/backoff, parallel workers, dashboard controls.
