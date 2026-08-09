# Hngh Work Session Plan

**Status**: M9 W1-2 done, W3 in progress (C7 done); M9.5 resume closed
**Last updated**: 2026-08-06

---

## Session Format

Each work session has:
- **Goal**: what to accomplish
- **Artifacts**: what to produce
- **Exit criteria**: how to know it's done
- **Dependencies**: what must be complete before starting

Sessions are designed to be 2–4 hours of focused work. Sessions may span multiple
sittings. Each session ends with a commit (or PR) and a journal entry.

---

## Pre-Implementation Sessions (done)

### Session 0A: Repo Setup + Project Management
**Status**: Done (2026-06-22)

### Session 0B: Build System + CI Scaffolding
**Status**: Done (2026-06-22)

---

## Milestone 0 Sessions — Foundation (all done, 2026-06-22)

| Session | Title | Status |
|---|---|---|
| M0.1 | SBCL Project Skeleton | Done |
| M0.2 | Event Bus (A2) | Done |
| M0.3 | State Store (A3) | Done |
| M0.4 | Plugin Host (A1) | Done |
| M0.5 | Supervisor (A6) | Done |
| M0.6 | Scheduler (A5) | Done |
| M0.7 | dbus Bridge (Minimal) | Done |
| M0.8 | Dashboard TUI (Minimal) | Done |
| M0.9 | System Daemon Skeleton | Done |
| M0.10 | End-to-End Integration | Done (18 integration tests) |

**Total M0**: 78 unit + 18 integration = 96 tests passing.

---

## Milestone 1 Sessions — The Harness (Batches 0–4 done; Batch 5 next)

M1 sessions are batched by dependency — each batch's deliverables are
prerequisites for later batches. Within a batch, sessions are independent
and can be parallelized.

### Batch 0: Foundation for M1 — done

- **M1.0a**: Migrate test suite from custom harness to FiveAM (D-013)
  — 78 existing tests rewritten to FiveAM's `def-test`, `def-fixture`,
  `before-each`/`after-each` pattern. Solves state contamination and flaky
  scheduler tests. **Done** (commit `8ebcbe4`, 2026-06-23).
- **M1.0b**: Design spec sync — already done during M0 critical review.

### Batch 1: Core Security + Resources — done

- **M1.1**: Procedural threat detection (L1+L3) — static analysis of
  plugin manifests and code, runtime observation of plugin behaviour,
  rules engine. **Done** (commit `f33bbd6`, 2026-06-23). 19 tests.
- **M1.2**: Resource manager (A4) — VRAM/CPU/memory arbitration,
  preemption, hardware audit. **Done** (commit `f33bbd6`, 2026-06-23).
  17 tests.

### Batch 2: System Management + Secrets — done

- **M1.3**: Package manager (B1) — pacman/yay/paru integration,
  breakage detection. **Done** (commit `f45c5c7`, 2026-06-23).
  15 tests.
- **M1.4**: System config (B2) — /etc management, btrfs snapshots,
  theming files. **Done** (commit `f45c5c7`, 2026-06-23). 14 tests.
- **M1.11**: Secrets manager (B8) — local-vault backend (fully
  implemented) plus 1Password/KeePassXC/vault-age stubs. Policy-checked
  access, audit log. **Done** (commit `f45c5c7`, 2026-06-23). 22 tests.

### Batch 3: AI Infrastructure — done

- **M1.5**: Model runtime manager (B4) — ollama, llama.cpp, unsloth,
  comfyUI spawn/lifecycle. **Done** (commit `868de1a`, 2026-06-24).
  13 tests. Then hardened (commit `905ea2f`).
- **M1.6**: AI tool hub (B11) — tool registry, agentic CLI invocation,
  direct API (Anthropic, Google, OpenAI), cost tracking, provider-
  specific auth headers. **Done** (commit `868de1a`, 2026-06-24).
  17 tests. Then hardened (commit `905ea2f`).
- **M1.7**: AI orchestrator (B3) — coordinator, context package
  assembly, inter-tool handoffs, `backend-id` mapping for completion
  events. **Done** (commit `868de1a`, 2026-06-24). 16 tests. Then
  hardened (commit `905ea2f`).

### Batch 4: Security AI + Knowledge — done

- **M1.8**: LLM threat detector (L2+L4) — `review-plugin`,
  `review-behavior`, periodic reviews via scheduler, `threat.flag`
  subscription, persistence under `config/plugins/llm-threat/` and
  `state/plugins/llm-threat/`, KB pattern recording for suspicious
  reviews. **Done** (commit `cc4afa8`, 2026-06-24). 6 tests.
- **M1.9**: Hnghbeats (B6) — daily condensation, deterministic
  summaries, persistence under `journal/hnghbeats/YYYY-MM-DD.lisp`.
  **Done** (commit `cc4afa8`, 2026-06-24). 3 tests.
- **M1.12**: Knowledge base (B12) — article/decision/pattern storage,
  keyword + tag query, lock-aware writes. **Done** (commit `cc4afa8`,
  2026-06-24). 7 tests.

### Batch 5: Backup + Polish — in progress

- **M1.10**: Backup manager (B7) — git versioning of state tree,
  remote sync, restore, secrets exclusion (defense-in-depth).
  **Done** (2026-06-24, Oracle-reviewed + hardened H1–H5). 16 tests.
- **M1.13**: KDE integration (B10) — theming, notifications (P2;
  included in v0.1 per user decision). **Not started.**
- **M1.14**: PKGBUILD + split packages — five packages
  (`hngh-core`, `hngh-system`, `hngh-python`, `hngh-kde`,
  `hngh-dev`), custom repo. P0. **Not started.**
- **M1.15**: Integration tests — end-to-end shell tests for all 8
  critical flows in `docs/design/integrations.md`. P0.
  **Not started.**

### Cleanup (revisited)

- `tests/unit/harness.lisp` is NOT orphaned — it holds the FiveAM
  harness (`def-suite`, `run-tests`, fixtures). Kept; optional rename
  deferred (D-026).
- `hngh.asd` `:perform (test-op ...)` now calls `hngh.tests:run-tests`
  (D-027). Done.

**Cumulative test count after M1.10**:
243 unit + 18 integration = 261 tests, all passing (1090 FiveAM checks).

---

## Journal Convention

Each work session ends with a journal entry in `docs/journal/YYYY-MM-DD.md`:
- What was done
- What was learned
- What's next
- Decisions made (if any, with mini-ADR)

Existing journal files:
- `docs/journal/2026-06-22.md` — Design phase + M0 sessions (0A, 0B, M0.1–M0.10)
- `docs/journal/2026-06-23.md` — M1.0a, M1.1+M1.2, M1.3+M1.4+M1.11
- `docs/journal/2026-06-24.md` — M1.5+M1.6+M1.7, hardening, M1.8+M1.9+M1.12
- `docs/journal/2026-07-31.md` — MC-1 tmux QoL, MC-2/3, llm-budget spend gate, DOC wave, NET-1
- `docs/journal/2026-08-01.md` — H-A2/B1/B2/A3, M-sentry Tier-0, queue v3, cost-routing v2
- `docs/journal/2026-08-02.md` — M7 daemon merge, Phase 2 claim/release, squad lifecycle, platoons, aesthetics
- `docs/journal/2026-08-03.md` — M9 W1-3 squad autonomy, C7 PM-first-prompt, lint-counts
- `docs/journal/2026-08-04.md` — M9 W2-5 staging
- `docs/journal/2026-08-05.md` — model mandate, squad test-loop fast-gate, dual-push policy
- `docs/journal/2026-08-06.md` — M9.5 resume, W5 prompt matrix, free-tier refresh, benchmark brief
- `docs/journal/2026-08-07.md` — M9.9-9.13, C6 planner waves, quota-spreader, live-orchestration, ACP A1-A4, cost policy, cogmem drop
- `docs/journal/2026-08-08.md` — L2/L3 situation-scoring design, research docs, handoff, MisakaNet nodes

---

## Session Cadence

Sessions are flexible. The user drives the schedule. The plan is a menu, not a
calendar — pick the next session, do it, mark it done, pick the next.

Dependencies are noted to prevent starting a session before its prerequisites are
complete. Within a batch, sessions are independent and can be parallelized.


## M2 Sessions — Local Model Access
### Session M2.1: Local OpenAI-Compatible Endpoints (AI Tool Hub)
**Status**: Done (2026-07-31) — changes uncommitted, awaiting owner commit
- **Goal**: Let ai-tool-hub call the local unsloth server (OpenAI-compatible, $0) so hngh loops fit the < $1/day remote policy.
- **Artifacts**: `sessions/m2-local-baseurl.md` (wave plan, supersedes `sessions/m2-local-baseurl-draft.md`); patch to `src/plugins/ai-tool-hub.lisp`; test update in `tests/unit/test-ai-tool-hub.lisp`.
- **Exit criteria (all met)**: registry has 9 tools incl. `:local-openai-api`; `select-tool` picks it; `estimate-cost` = 0.0; `execute-direct-api :local-openai-api` live-returns "ok" from unsloth:8888; `make test` 844/844 green.
- **Dependencies**: unsloth at 127.0.0.1:8888 via systemd `unsloth-studio.service` + `unsloth-warm.service` (installed 2026-07-31, keeps gemma-4-12b warm).
- **Changes**: `local-endpoint-available-p` TCP probe (sb-bsd-sockets, eval-when require); registry entry (`:type :direct-api`, `:cost-model :free`, `:providers (:local :openai-compatible)`, `:dogfooding t`); `*provider-endpoints*` alist replaces hardcoded `api-endpoint`; ecase branches added in `default-model`, `format-json-payload`, `provider-api-headers`; `get-api-key` short-circuit (`UNSLOTH_API_KEY` env, fallback "local-dummy-key").

### Session M3.1: Event Loop (Task Driver on the Scheduler)
**Status**: Done (2026-07-31) — changes uncommitted, awaiting owner commit
- **Goal**: Replace the "no event loop" stub with a working driver: persistent task queue + scheduler-driven execution, defaulting to $0 local inference.
- **Artifacts**: `sessions/m3-event-loop.md` (wave plan); `src/plugins/ai-orchestrator.lisp` (queue+driver), `src/core/main.lisp` (driver registration + `--once` + blocking loop), `src/packages.lisp` (driver exports), `tests/unit/test-task-driver.lisp`, `hngh.asd` (test registration); **invoke-agent dispatch fix** (`:local-openai-api` added to the tool member list — integration gap found during implementation review: M2 registered the tool but the orchestrator couldn't dispatch it).
- **Exit criteria (all met)**: `make test` 860/860; task submitted in one process persisted; `hngh --once` in a second process drained it to `:done` via real :8888 inference (transcript: tool `:local-openai-api`, status `:completed`, cost 0.0, result "ok"); clean shutdown.
- **Dependencies**: M2 (`:local-openai-api`), unsloth via systemd units (M0).
- **Notes**: Queue lives at `~/.hngh/tasks/queue.lisp` (state-store root is `~/.hngh/`, not `~/.hngh/state/` as the wave file guessed). Default policy `(:prefer-tool :local-openai-api)` = deterministic $0. Driver is serial, one task per tick; retries/backoff, parallel workers, and dashboard controls are later waves.

### Session M4.1: Unsloth Lifecycle in Model Runtime (shared-server management)
**Status**: Done (2026-07-31) — changes uncommitted, awaiting owner commit
- **Goal**: Manage unsloth the ollama way — shared systemd-owned server, API-level lifecycle, never spawn/kill the process.
- **Artifacts**: `sessions/m4-unsloth-lifecycle.md` (wave plan); `src/plugins/model-runtime.lisp` (unsloth API helpers: `unsloth-request`/`unsloth-health-p`/`unsloth-models`/`unsloth-model-loaded-p`/`unsloth-warm-model`/`unsloth-ensure-server`, `spawn-unsloth-runtime`, spawn/stop ecase splits, health-based discovery); 3 new tests in `tests/unit/test-model-runtime.lisp`.
- **Exit criteria (all met)**: `make test` 868/868; live cycle — discover ⇒ `:unsloth t`, spawn ⇒ `:ready`/8888/pid nil, stop ⇒ clean, server healthy after; original systemd process (pid 182017) untouched throughout.
- **Dependencies**: M0 (unsloth-studio.service + unsloth-warm.service).
- **Notes**: Design constraint — hngh must NOT spawn its own unsloth (port collision with the systemd unit); management is `/v1/models` + load-on-call only; no warm-by-default (20GB eviction risk — `:warm t` is explicit opt-in); comfyUI keeps the manual stub. `unsloth-api-key` reads env var, then by-name from `~/.hermes/.env`, then dummy. Env var has no setf on this SBCL — tests stub `uiop:getenv` via symbol-function.

### Session M5.1: First Dogfood Loop — Real Task on $0 Local Inference
**Status**: Done (2026-07-31) — changes uncommitted, awaiting owner commit
- **Goal**: Prove the whole thesis — a real, useful task flows through hngh's queue -> task-driver -> delegate -> local model at $0, producing a reviewable artifact.
- **Task**: Draft the svc-dash wave-5 spec (detail polish: start/stop buttons, log-follow mode, panel sparklines). Self-contained prompt; direct-api single completion (no file tools).
- **Execution**: `submit-task` in one sbcl process (task id 2, persisted); `hngh --once` in a second process drained it: real HTTP call to :8888, 13s, 1,727 tokens (236 prompt + 1,491 completion), cost 0.0.
- **Artifact**: `~/Projects/etc/svc-dash/sessions/wave-5-detail-polish.md` (3,332 chars) — all seven required sections present; reviewed and adopted by opencode as the wave-5 spec.
- **Exit criteria (all met)**: queue shows `:done` with non-empty result; artifact saved with attribution; total spend $0.
- **Dependencies**: M2 (local endpoints), M3 (event loop), M0 (unsloth warm).
- **Notes**: Extraction lesson — Lisp prints JSON with `\\n` for JSON's `\n`; never string-surgery Lisp output in Python — have SBCL `read` the queue natively and emit clean JSON (see /tmp extraction pattern this session). Queue `:result` stores the full chat-completion JSON (usage included), not just message text.

### Session M6.1: Mission Control (tiled tmux observability + agent summoning)
**Status**: Done (2026-07-31) — changes uncommitted, awaiting owner commit
- **Goal**: One command (`mc`) opens a tiled tmux session with dashboard, daemon, status, event journal, and summonable agent panes — scrollable, auto-tiling, at-startup or on-demand.
- **Artifacts**: `~/.local/bin/mc` (launcher: panes = svc-dash | hngh daemon | `watch hngh-status` | events tail | free); `src/plugins/mission-control.lisp` (+ defpackage in packages.lisp, component in hngh.asd, init/shutdown in main.lisp incl. rollback); `tests/unit/test-mission-control.lisp` (live tmux lifecycle test); `~/.config/autostart/hngh-mc.desktop`; `sessions/m6-mission-control.md` (wave plan); gbd tracks `mc` + `hngh-status` (agent-configs commit f8a1a56).
- **Exit criteria (all met)**: `make test` 880/880 (incl. live tmux lifecycle); mc session live with all panes (svc-dash rendered, daemon event loop active); task #4 (wave-5 implementation diff, 13.8KB self-contained prompt) processed by the daemon to `:done` — 19.2K-char unified diff, 13,874 tokens, $0, saved at `svc-dash/sessions/wave-5-implementation-draft.diff.md`.
- **Dogfood catch**: task #3 failed (server 400). Root cause: `(make-string (file-length s))`+`read-sequence` leaves NUL padding on multi-byte UTF-8 (file-length is bytes, not chars). Fixed two ways: `escape-json-string` hardened to emit `\u00XX` for all control chars (+ regression test), and the correct idiom documented (`(subseq str 0 (read-sequence str s))`).
- **Dependencies**: M0–M5 machinery; tmux; svc-dash.

### Session M6.2: Agentic File-Editing Loops (opencode via tool hub)
**Status**: Done (2026-07-31) — changes uncommitted, awaiting owner commit
- **Goal**: Let the driver run tasks that WRITE code, not just text — agentic CLI path (opencode headless) at $0 via the local model.
- **Root-cause arc**: task #5 failed with `:OPENCODE fell through ECASE`. Two latent bugs: (1) `agentic-cli-args` used stale `--task` syntax → fixed to opencode 1.18 `run --auto -m unsloth-local/unsloth/gemma-4-12b-it-qat-GGUF`; (2) the REAL outcome was masked by `log-cost-entry` calling `default-model` unconditionally — its ecase covered only the 4 API tools, so every agentic invocation crashed at cost-logging (success marked failed, true error hidden). Fixed with a total case fallback (agentic CLIs report their tool id).
- **Artifacts**: `src/plugins/ai-tool-hub.lisp` (2 fixes), `tests/unit/test-ai-tool-hub.lisp` (args-shape + default-model-total tests), `sessions/m6-2-agentic-loops.md` (wave notes).
- **Exit criteria (all met)**: `make test` 888/888; task #6 (write /tmp/hngh-agentic-proof.txt with "ok") ran queue → driver → `opencode run --auto -m <local-12b>` → file exists with "ok"; queue shows `:done` with correct attribution.
- **Notes**: Agentic invocations run with `--auto` (headless auto-approve; secret-path denies still enforced by opencode config). `execute-agentic-cli` has NO timeout — a hung agentic task blocks the tick; timeout support is follow-up hardening.
- **Dependencies**: M2 local endpoints, M3 driver, opencode 1.18 + unsloth-local provider config.

### Session M6.3: Emacs Daemon Lifecycle Plugin (MC-2 wave 2)
**Status**: Done (2026-07-31) — changes uncommitted, awaiting owner commit
- **Goal**: Give hngh lifecycle management for the emacs daemon (start/stop/health) so future waves (agent panes, elisp evaluation, org integration) can rely on a headless emacs server — without ever touching the user's GUI emacs.
- **Artifacts**: `src/plugins/emacs-daemon.lisp` (new: `daemon-alive-p`/`start-daemon`/`stop-daemon`/`health` + standard init/shutdown/running-p/status); `src/packages.lisp` (defpackage); `src/core/main.lisp` (init + rollback + stop wiring, mirroring mission-control); `hngh.asd` (component + test entries); `tests/unit/test-emacs-daemon.lisp` (new: 3 unit + 1 guarded live lifecycle test).
- **Exit criteria (all met)**: `make test` 901/901, 0 fail, 0 skip; plugin compiles clean; guarded live test passes headless; pre-existing daemon never stopped.
- **Dependencies**: emacs 30.2 + emacsclient on PATH (`--daemon` detaches; readiness = `emacsclient --eval` exit 0).
- **Notes**: Daemon start is policy-explicit — `init` logs state but never auto-starts; `shutdown` is bookkeeping only, the daemon outlives hngh (like the tmux session outlives mission-control). Safety property: `emacsclient --eval` (incl. `(kill-emacs)`) reaches only the daemon's server socket, so a non-daemon GUI emacs is untouched. A daemon (pid 439063) was ALREADY running when this session started, so the live test exercised its guarded health-only branch (asserts shape, never stops); the start/stop branch runs only when no daemon pre-exists. `daemon-alive-p` runs emacsclient with a 5s kill-on-timeout guard. — M6.3 patch: opencode (kimi-k3, attended), work package WP-B from Hermes TUI orchestrator (moonshotai/kimi-k3).

### Session M-sentry: Sentry Procedural Safeguards Plugin (Tier-0)
**Status**: Done (2026-08-01)
- **Goal**: Build the continual-safeguards layer's Tier-0 into hngh as a procedural plugin — secret-guard + context-watch, NO model calls in the hot path (llmtrim's shape). See `.omc/plans/sentry-safeguards.md`.
- **Artifacts**: `src/plugins/sentry.lisp` (new: `scan-secrets`/`guard-text` with 9 secret patterns + redacted evidence via `threat.flag` publish; `context-pressure`/`latest-context-size` reading the hermes agent.log tail, green/yellow/red against a 256k ceiling); `src/packages.lisp` (defpackage :hngh.plugins.sentry); `hngh.asd` (component + test); `src/core/main.lisp` (init + both shutdown chains, mirroring emacs-daemon); `tests/unit/test-sentry.lisp` (12 fixture-based tests).
- **Exit criteria (all met)**: `make test` 920/920 (901→920), 0 fail, 0 skip; each secret pattern fires on a synthetic fixture; clean text passes; redaction test proves no secret value leaks into returned hits; context-pressure green/red/unknown verified on synthetic logs.
- **Design notes**: Plugins raise flags via `event-bus:publish "threat.flag"`, NOT by calling threat-detection's unexported `raise-flag` (corrected during implementation — mirrors how llm-threat-detector observes flags). Evidence is pattern-names + text-length only, never content. `context-watch` reads only the last ~64KB of the 4.6MB log to stay cheap. Procedural + fail-closed throughout; this is the tier that later feeds light-ralph (Tier-1) analysis and the human gate (Tier-2).
- **Author**: moonshotai/kimi-k3 via OpenRouter (Hermes TUI). Built directly (procedural code needs no model delegation); the analysis tasks for this layer are delegated to night-ralph.

### Session MC-2 w3: Emacs Dashboard Panels + Window Management
**Status**: Done (2026-07-31)
- **Goal**: Live agent visibility + frame management on the emacs dashboard (MC-2 wave 3, first slice).
- **Artifacts**: `emacs/hngh-mc.el` — `*opencode*` panel (right side-window slot 2, tails `~/.local/share/opencode/log/opencode.log` via auto-revert-tail-mode, placeholder when unreadable); `hngh-mc-balance-windows` (equalize right-panel heights, idempotent); `hngh-mc-rotate-windows` (cycle buffers among windows, `C-u` reverses; temporarily clears side-window dedication to swap). `emacs/README.md` commands table.
- **Exit criteria (all met)**: byte-compile 0 warnings; batch open shows all 5 panels; balance equalizes (6/6/6/5 rows); rotate cycles and `C-u` restores exactly; reloaded into the running daemon (live frame shows 5 panels).
- **Bug found+fixed**: rotation initially failed — side windows are `dedicated . t`, so `set-window-buffer` refused; now dedication is cleared for the swap and restored for side windows.
- **Notes**: Read-only tail — elisp never writes the opencode log. Author: moonshotai/kimi-k3 via OpenRouter (Hermes TUI).
### Session M-sentry+: Restart/Cascade Lifecycle Seam + Tests (Task 83 gap)
**Status**: Done (2026-08-02) — changes uncommitted, awaiting owner commit
- **Goal**: Close the Designer-audit gap (#347): `restart-session` and `cascade-restart` had zero test coverage because `session-alive-p`/`start-session`/`stop-session` invoked tmux/mc directly instead of routing through the injectable `*squad-command-runner*`.
- **Seam**: `session-alive-p` now runs `has-session` through `*squad-command-runner*`; `start-session`/`stop-session` route the mc subcommand through the same runner (default unchanged behavior; exit-code/stdout contract preserved for callers).
- **Tests added (5)**: `restart-session-signals-when-not-alive`; `restart-session-saves-stops-starts-restores` (verifies layout persisted + stop-before-start order); `restart-session-proceeds-without-saved-layout` (save failure degrades gracefully, still stops/starts); `cascade-restart-restarts-parent-before-children` (tree order, all sessions alive-checked); `cascade-restart-tolerates-child-failure` (not-alive child logged, cascade continues).
- **Also fixed**: `src/client/main.lisp` `--hngh-home` help string had `~/.hngh/` inside a `format` control string — `~/` is a call-function directive, so the literal `~` must be escaped as `~~` (fatal compile error, caught at 20:59; fix committed in HEAD at d569e3b).
- **Exit criteria (all met)**: full `make test` 1393/1393 green (1203 → 1393 with M9 W1-2 plugins + C7 generator), 0 fail, 0 skip; MC suite 85/85; no new style warnings from changed files.
- **Notes**: Patch preserved at `~/.hngh-night/artifacts/83-restart-cascade-seam-tests.patch` after repeated concurrent working-tree reverts by the Artist seat during verification. Pre-existing environmental flakes (daemon socket connect, LTD persistence, emacs live lifecycle) are unrelated to this change. — Sisyphus worker, opencode (deepseek/deepseek-v4-flash), $0.

### Session M7.1: hngh-up Design Doc + Plugin + CLI (Goal-Driven Squad Spin-Up)
**Status**: Done (2026-08-02)
- **Goal**: Add `hngh up <goal>` command for goal-driven squad spin-up with procedural questionnaire, strategy system, autonomous continuation, and social sharing.
- **Artifacts**: `docs/design/hngh-up.md` (design spec); `src/plugins/hngh-up.lisp` (plugin: context gathering, adaptive questionnaire ≤5 questions, spec derivation, strategy management, squad launch via existing `squad` script); `src/client/main.lisp` (`up` subcommand, local command — no daemon dependency); `src/packages.lisp` (`:hngh.plugins.hngh-up` defpackage); `hngh.asd` (plugin registration); `src/core/main.lisp` (init/shutdown hooks for config-watcher and hngh-up).
- **Mission-control changes**: Made `session-alive-p`, `start-session`, `stop-session` use injectable `*squad-command-runner*` so squad's restart tests can mock tmux calls.
- **Squad's Task 83**: Restart tests now green (165 new lines in `tests/unit/test-mission-control.lisp`).
- **Exit criteria (all met)**: `make test` 1393/1393 green (includes squad's restart tests + hngh-up, agents-md, squad-resources, fragment-journal plugins + C7 PM-first-prompt generator); `make build` and `make build-client` both pass.
- **Attribution**: PM — z-ai/glm-5.2 via openrouter, Hermes harness.

### Session M9.3: Squad Automation Bootstrapping (C7 PM-first-prompt, file-change notification, journal lifecycle)
**Status**: In progress (2026-08-03)
- **Goal**: Automate squad startup end-to-end. PM's first prompt procedurally generated from project/system/OptMem context. Per-role prompts seeded by PM after orientation. File-change notification system (gbd systemd .path pattern). Squad journal lifecycle integration. Test-count lint (procedural, no LLM). Bootstrap hngh's self-improvement loop.
- **Context**: M9 W1-2 done (C1 AGENTS.md discovery, C2 resource gate, C5 fragment journal, hngh-up with partial C3). 1368/1368 tests green. squad-up script exists with static prompts. config-watcher does mtime-poll on 2 hardcoded paths.
- **Artifacts**: `.hermes/plans/2026-08-03_squad-automation-bootstrapping.md` (plan); `.hngh-night/artifacts/pm-to-designer-squad-startup-automation.md` (design request to Designer); `docs/design/squad-startup-automation.md` (full design doc: dispatch tree, bean bus, git-backed rollback, prompt matrix, role senses); `scripts/lint-test-counts.sh` (Wave 0 lint); `src/plugins/hngh-up.lisp` (Wave 1: generate-pm-prompt); `journal/squads/pm-squad-automation-bootstrap-20260803T120000Z-projected.md` + `-actual.md` (squad journals); fixed stale test counts in AGENTS.md, roadmap, work-sessions.
- **Waves**: W0=lint (done), W1=C7 PM-first-prompt (done, 1393 green), W2=file-change notification, W3=dispatch tree+git, W4=bean lifecycle, W5=prompt matrix, W6=squad-up integration, W7=self-improve loop, W8=benchmark squad, W9=nightly cron.
- **Attribution**: PM — z-ai/glm-5.2 via openrouter, Hermes harness. Worker — gemma-4-12b (local, $0) for C7 implementation.

### Session M9.4: Test-loop optimization completion (fast-suite gate)
**Status**: Done (2026-08-05)
- **Goal**: Complete the halted 20260804 squad's test-loop work; make incremental and gate-keeping tests fast.
- **Context**: Squad run 20260804T150741Z-cheap left uncommitted work (focused test-fast targets, model-runtime pull fence, squad-dispatch pathspecs). Post-mortem reviewed; verification exposed five real bugs in committed code.
- **Artifacts**: Makefile test-fast/test-suite/test-full split (15s timeout); scripts/lint-test-counts.sh sums the fast suite; fixes in beans.lisp, squad-dispatch.lisp, model-runtime.lisp.
- **Bugs fixed**: fiveam run! form quoting; %git run outside squad root; %atomic-write rename mangling extensionless targets; ANSI-CL newline literal in bean inbox append (wrote 'n'); nreverse count footgun; %find-role-dirs uiop signature mismatch; lint parse.
- **Exit criteria (met)**: make test 205/205 @ 2.6s; make test-full 1406/1406; lint-counts clean.
- **Attribution**: squad run 20260804T150741Z-cheap (deepseek-v4-flash via openrouter); verification + fixes — deepseek-v4-flash-0731 via openrouter (Hermes TUI). Commit b7a0289.

### Session M9.5: M9 resume — mandate-to-code sync, plugin wiring, build-fence fix
**Status**: Done (2026-08-06) — committed 9116f94
- **Goal**: Close the three documented M9 gaps: code-embedded model chains still
  on the old kimi/gemma routing (journal 20260805-model-mandate.md "Open"),
  Wave 2-4 plugins staged but never wired into the daemon lifecycle, and a
  C3 inference bug found during smoke testing.
- **Artifacts**: `src/plugins/hngh-up.lisp` (model-mapping + strategy labels ->
  mandate; C3 rule negation/remote-primary branches); `src/plugins/ai-tool-hub.lisp`
  (opencode default -> deepseek-v4-flash-0731); `src/plugins/squad-resources.lisp`
  (vram table kimi -> glm-5.2/qwen3.7); `src/core/main.lisp` (file-watcher,
  squad-dispatch, beans, squad-resources wired init/stop/rollback); `Makefile`
  (LISP_FILES glob += src/plugins/*.lisp — plugins now trigger rebuilds);
  `docs/design/prompt-matrix.md` (chains/tables synced); `docs/design/
  squad-startup-automation.md` (wave table 2/3/4 -> done); `docs/project/
  roadmap.md` + `AGENTS.md` (status + counts 207); `tests/unit/test-hngh-up.lisp`
  (+mandate-phrasing fixture), `tests/unit/test-ai-tool-hub.lisp` (default
  assertion); `journal/20260806-m9-resume.md`.
- **Bugs found+fixed**: (1) C3 `answer-from-agents-md` matched bare "daily
  driver" and inferred local-only against the mandate-era AGENTS.md ("not the
  daily driver") — added negation + remote-primary branches, smoke run now
  auto-answers budget-50; (2) Makefile `LISP_FILES` glob excluded src/plugins/
  so plugin edits never rebuilt the binary — smoke ran stale; fixed glob,
  verified touch-rebuild + no-op.
- **Exit criteria (met)**: make test-fast 207/207; make test-full 1416/1416;
  lint-counts clean; make build/build-client both rebuild after plugin touch;
  `hngh-client up --dry-run` auto-answers all four questions and emits the PM
  first prompt with the mandate model tier.
- **Attribution**: deepseek-v4-flash-0731 via deepseek (Hermes TUI).

### Session M9.6: W5 prompt matrix build (skeleton-bones-flesh)
**Status**: Done (2026-08-06) — uncommitted, owner review pending
- **Goal**: Build the W5 prompt matrix per `docs/design/prompt-matrix.md`:
  `generate-prompt` extending `generate-pm-prompt` into a full dimensional
  prompt generator (36 skeletons, deterministic bone fillers, optional flesh
  pass, per-role model selection synced to D-040, prompt cache).
- **Artifacts**: `src/plugins/hngh-up.lisp` (prompt-dimensions struct,
  *skeleton-library* 36 templates, 41 bone fillers incl. bean vocabulary +
  aesthetic briefs, *per-role-fallback-chains* D-040 synced, select-role-model
  + gates, flesh pass (should-flesh-p/select-flesh-model/validate-flesh-output/
  invoke-flesh-model), prompt cache, generate-prompt; generate-pm-prompt now
  delegates to generate-prompt); `src/packages.lisp` (hngh-up export list +
  23 W5 symbols); `tests/unit/test-hngh-up.lisp` (%d5-tmp-project fixture,
  T1-T11: dimension selection, skeleton selection, bone filling with/without
  task-spec, flesh skip local/no-budget, model selection per role, fallback
  chain, prompt cache, backward compat, all-36-fill); `AGENTS.md` + `roadmap.md`
  (status + counts 390/390 fast, 1591/1591 full).
- **Bugs found+fixed**: (1) `evaluate-fallback-chain` looked up
  `*per-role-fallback-chains*` with `getf` — returns NIL on the alist-shaped
  table; switched to `second (assoc ...)` (double-wrapped alist pitfall);
  (2) `:local-only` resources let free ($0) remote models through the budget
  gate — added explicit remote-block branch; (3) prompt cache key omitted
  squad-name — cached prompts leaked the previous squad's name across calls.
- **Spec deviation (flagged)**: prompt-matrix.md T7 asserted artist falls back
  to "glm-5.2"; the D-040-synced artist chain (§7.3, no glm-5.2) selects
  deepseek-v4-flash-0731 instead. Test asserts the synced chain head. Spec
  test was stale from the pre-mandate chain; chains are the source of truth.
- **Exit criteria (met)**: make test-fast 390/390; make test-full 1591/1591;
  lint-counts clean; backward compat — all C7 generate-pm-prompt tests pass
  unchanged against the delegating implementation.
- **Attribution**: deepseek-v4-flash-0731 via deepseek (Hermes TUI).

### Session M9.7: Free-tier refresh + model benchmark sourcing
**Status**: Done (2026-08-06) — committed
- **Goal**: Replace the stale, single-vendor free fallback tier (nemotron-
  stack with short IDs that 404 on OpenRouter) with the best current free
  models distributed across vendors; promote Qwen-AgentWorld-35B to primary
  local; add a procedural benchmark-sourcing script so model choice is
  grounded in real data, not vibes.
- **Artifacts**: `src/plugins/hngh-up.lisp` (*per-role-fallback-chains*
  refreshed to live catalog IDs: nvidia/nemotron-3-ultra-550b-a55b:free,
  google/gemma-4-31b-it:free, openai/gpt-oss-20b:free, poolside/laguna-s,
  cohere/north-mini-code:free, inclusionai/ling-3.0-tiny:free, google/gemma-
  4-26b-a4b-it:free, nvidia/nemotron-3-super/nano-omni; Qwen-AgentWorld-35B
  as primary local fallback in designer/coder/accountant/worker; flesh chain
  -> gemma-4-31b-it:free + Qwen-AgentWorld; *model-mapping* :local-only ->
  Qwen-AgentWorld; select-system local-models list = 4 real locals);
  `src/plugins/squad-resources.lisp` (*model-vram-mb* + qwen-agentworld/
  ornith entries — they were classified remote before); `scripts/
  fetch-model-benchmarks.sh` (new: OpenRouter catalog + LM Arena PPE +
  Aider leaderboard -> dated snapshot); `data/model-benchmarks-20260806.json`
  (snapshot: 400 catalog, 68 aider, 2 ppe); `docs/design/model-pareto.md`
  (free-tier table + per-role chains + sourcing note); `docs/design/
  prompt-matrix.md` (§7.3 chain block replaced with source-of-truth pointer
  — it had drifted twice); `docs/design/squad-startup-automation.md` +
  `hngh-up.md` (stale kimi/nemotron references); `tests/unit/test-hngh-up.
  lisp` (+2 regression tests: d5-free-tier-distributed, d5-local-workhorse-
  agentworld).
- **Verification**: make test-fast 464/464 (+74); make test-full 1665/1665
  (+74); lint-counts clean; benchmark script run twice with identical
  output.
- **Notes**: PPE datasets only cover legacy models (gpt-4o-mini, gemma-2,
  llama-3-8b) — good mechanism, thin coverage for today's free tier; the
  script's value is the catalog + aider overlap plus a repeatable pipeline
  to refresh capability estimates. Capability scores for the new free
  models are estimates until a benchmark covers them.
- **Attribution**: deepseek-v4-flash-0731 via deepseek (Hermes TUI).

### Session M9.8: Benchmark sourcing design brief
**Status**: Done (2026-08-06) — committed
- **Goal**: Expand benchmark sourcing so local GGUF models (8-35B on the
  RX 7900 XT) are compared against published leaderboards and remote free
  models procedurally, no LLM judging.
- **Artifacts**: `docs/design/benchmark-sourcing.md` (new) — verified
  data paths for HF Open LLM Leaderboard v2 (`contents` parquet URL
  pattern + columns + Raw-vs-normalized units; `results` rows API broken
  dataset-side, use `first-rows`), offline harnesses (lm-eval
  `local-chat-completions` invocation, promptfoo YAML matrix, aider
  polyglot), procedural perf measurement (ollama /api/chat timing fields
  in ns; sysfs `/sys/class/drm/card1/device/mem_info_vram_*` rootless
  VRAM; rocm-smi cross-check), snapshot JSON schema for
  `model-benchmarks-local-YYYYMMDD.json`, and the remote-free scoring
  path with OpenRouter attribution headers.
- **Verified on-host**: HF datasets-server endpoints, ollama 0.30.6 API
  (note: `/metrics` 404s on this host — use /api/chat timing fields),
  sysfs card1 = RX 7900 XT (20 GiB), rocm-smi GPU[0] matches.
- **Attribution**: deepseek-v4-flash via deepseek (Hermes TUI, direct —
  delegation re-pointed off OpenRouter after its weekly spend wall hit,
  see ~/.hermes/config.yaml delegation section).

### Session M9.9: Model probe runner implemented
**Status**: Done (2026-08-07) — committed
- **Goal**: Implement the probe-suite runner that docs/design/benchmark-
  sourcing.md specifies (run-probe was a TODO stub).
- **Artifacts**: `data/model-probes.lisp` — real `run-probe` (ollama native
  `/api/chat` vs OpenAI-compatible `/chat/completions` by endpoint, curl +
  sb-ext, jsown parsing, per-probe timing: tokens/sec + prefill ms from ns
  fields), `run-probe-suite` (perf plists), `write-benchmark-snapshot`
  (dated JSON + sysfs VRAM host block + weighted aggregate), `validate-
  json-schema` (was referenced but never defined), `make-scorer-json-schema`
  factory, `%json-escape`. Also fixed latent broken syntax throughout the
  file: `[...]` pseudo-list literals (SBCL reads them as symbols — the file
  had never loaded), unbalanced defparameter, and the `export` form taking
  symbols instead of a list.
- **Verification**: `make test-fast` 494/494 (was 464; +30 new model-probes
  tests), `make test-full` 1687/1687, `make lint-counts` clean.
- **Notes**: The file is a static data module (`:static-file`), so
  test-model-probes.lisp loads it explicitly at compile time. Escape-test
  builds input from char codes to avoid source-literal ambiguity.
- **Attribution**: deepseek-v4-flash-0731 via deepseek (Hermes TUI).

### Session M9.10: Public-release close-out (docs + PII scrub + dual remotes)
**Status**: Done (2026-08-07) — committed `1c693dc`, pushed github + codeberg
- **Goal**: Bring the repo to a clean public checkpoint for pushing.
- **Findings (via repo-public-readiness skill)**: README was 2026-08-01
  (M0-M6.2 / 920 tests) but reality is M9 / 494 fast + 1687 full; next.md
  was M0-M7 / 1028 — both stale in lockstep. 5 tracked session/journal
  records leaked the owner's home path. `origin.pushurl` pointed at Codeberg only,
  so `git push origin` silently skipped GitHub (D-002 violation) and the
  GitHub mirror had drifted 11 commits behind.
- **Doc wave**: README current-state -> M9 autonomy W1-5 + benchmark sourcing
  + probe runner (494/494 fast, 1687/1687 full), plugin count 13->24, core
  7->13, "Probe local models" hook added, Roadmap gained M7/M8/M9 rows.
  next.md reconciled in lockstep (status, Up Next M9 C4/C6/C8/C9, Done line,
  env facts SBCL 2.6.7 + jsown, Blocked note for the OpenRouter weekly spend
  wall). Chained in one commit so they can't drift apart again.
- **PII scrub**: owner's home path -> `~/` in sessions/h-a2, h-a3, and 3 squad
  journals (had to chmod the 0444 projected journals writable). Sweep across
  tracked tree now clean; secret sweep shows only the expected test-sentry
  self-fixtures.
- **Remote fix**: added the missing GitHub pushurl to `origin` so
  `git push origin` syncs both mirrors per D-002. Verified both GitHub and
  Codeberg at `1c693dc`.
- **Attribution**: deepseek-v4-flash-0731 via openrouter (Hermes TUI).

### Session M9.11: Autonomy-strategy research (6-thread synthesis)
**Status**: Done (2026-08-07) — committed with `docs/design/autonomy-strategy.md`
- **Goal**: Research the full arc toward Hngh as a self-developing,
  self-healing system-harnessing engine (up to a consulting workforce with
  peer instances), and fold it into a wave-ordered roadmap.
- **Method**: 3 delegated research subagents (self-dev systems, security/
  takeover resistance, multi-agent coordination) + orchestrated web research
  on the remaining threads (memory taxonomy, clean-arch self-modification,
  cheap inference/cost, MCP/A2A/ecosystem interop).
- **Artifacts (committed)**:
  - `docs/design/autonomy-strategy.md` — 683-line synthesis: north star, 6
    research sections, wave-ordered roadmap implications (C6 planner →
    guardrails → security baseline → benchmark/cost → MCP/A2A → fleet), open
    questions.
  - `docs/design/security-agentic-research.md` (26KB) + `docs/design/
    coordination-patterns-research.md` (29KB) — cited deep-dive reports.
  - `docs/project/roadmap.md` — design-artifacts table gains the four docs.
- **Key findings**: C6 (the recursive planner) is the keystone that makes
  Hngh run itself; guardrails must be deterministic fitness functions
  (not advisory docs); security baseline (immutable policy layer, least
  agency, provenance tagging, canaries, sandboxing, allowlisted deps) is a
  MUST-HAVE gate before any core self-modification or networking; cost comes
  from routing (DeepSeek-first) + prompt-cache awareness (~$0.0036/M cache
  hits); MCP (agent→tool) + A2A (agent→agent) are Hngh's M3 interop layer.
- **Attribution**: deepseek-v4-flash-0731 (orchestrator) + 3 delegated
  subagent passes (deepseek-v4-flash) via Hermes.

### Session M9.12: Quota-spreader design (cost control vs price bumps + K3 weekly reset)
**Status**: Design captured (2026-08-07) — `docs/design/quota-spreader.md`.
Per-route quota envelopes (hour/day/week/month reset + even-sparse drawdown)
gate quota'd routes like Kimi k3 and feed the C6 Wave-2 planner budget gate.
Extends llm-budget (rolling hour only) with reset-period awareness. Build
steps folded toward C6 Wave-2; not yet implemented.

### Session M9.13: Live-orchestration design capture (observation, steering, guard-rails)
**Status**: Design captured (2026-08-07) — `docs/design/live-orchestration.md`.
The underway-not-after-the-fact layer: procedural guard-rails (evidence cross-
checking, multi-pass dev/review, escalate), hngh-mc + TUI observation surfaces,
priority-scored Hermes/opencode steering, continual parameter optimization, and
Hermes/opencode integration plugins. Wave-ordered L1 (observe) → L2 (guard-
rails) → L3 (steer) → L4 (plugins) → L5 (self-steer + param optimizer). Not yet
built; captures the brief's architecture.

### Session M9.14: Steering-surface de-risk probe (ACP + opencode HTTP, L3/L4)
**Status**: Probe done + recorded (2026-08-07). Verified empirically:
- `hermes acp --check` → "Hermes ACP check OK"; opencode exposes `opencode acp`
  (ACP server) and `opencode serve` (HTTP/SSE control plane: /session/:id/message,
  /prompt_async, /abort, /event SSE, /tui/append+submit-prompt, permissions).
- Conclusion (in `live-orchestration.md` §3): build the Hngh steering plugin as
  an **ACP client** (uniform cross-tool) + opencode HTTP client. opencode
  mid-turn is interrupt-then-reprompt (/abort), not injection (upstream #21388
  open). Hermes /steer injects after next tool call.
- Process lesson (owner noteworthiness): loose `pkill -f`/`pgrep -af` matched
  my own shell line and I looped on the same pattern — a live-orchestration
  type failure the design is meant to catch. Kept the doc note; stopped,
  checked the error shape, switched to precise scoping.

### Session M9.15: ACP-everywhere + LSP design (broaden ACP use)
**Status**: Design captured (2026-08-07) — `docs/design/agent-client-protocol.md`.
Position: ACP (Zed's open standard, JSON-RPC2/stdio, 25+ agents) is Hngh's
uniform agent control+observe+gate layer — one ACP client drives any ACP-
capable agent (Hermes, opencode, Gemini CLI, Claude Code via adapter);
ACP server dogfoods Hngh (Emacs/Zed). Steer-vs-queue negotiated per agent
(never assumed; pi #4444 caveat); `session/request_permission` = human-gate.
LSP: Hngh as first-class LSP client — diagnostics/symbols power evidence-check
+ review/verify gates (ties L2 + P7). Waves A1 (client) -> A2 (task-driver
integration) -> A3 (steering) -> A4 (server). ACP and MCP kept separate
(control vs tools). Docs/comments only.

### Session M9.16: ACP transport/SDK research — CL-first confirmed
**Status**: Research done (2026-08-07), decision recorded in agent-client-
protocol.md. Findings: (1) Hngh has NO JSON-RPC lib today (only jsown JSON) —
corrected earlier "plumbing exists for MCP" note; (2) cxxxr/jsonrpc (Quicklisp
20260101) loads clean and ships client.lisp + transport/stdio.lisp — the exact
stdio JSON-RPC client transport ACP needs, in-CL; (3) no CL ACP client lib
exists (Python official agent-client-protocol + Rust/JS are the mature SDKs);
(4) Hermes' own ACP server is a Python adapter (acp_adapter) — wire contract
language-agnostic. Decision: build A1 CL-first on cxxxr/jsonrpc (consistent
with the CL plugin image; avoid a second runtime), pin protocolVersion, stay
explicit/schema-locked (ACP stabilizing via use_unstable_protocol). Fully
de-risked; D1 (CL-first) confirmed.

### Session M9.17: ACP client built (Wave A1, CL-first on cxxxr/jsonrpc)
**Status**: Built + verified (2026-08-07). src/plugins/acp-client.lisp: uniform
ACP client over stdio JSON-RPC — acp-initialize (protocol v1 negotiation +
agentCapabilities parsing), acp-midturn-mode (steer/interrupt/unknown, never
assumes), acp-session-new/load/prompt/cancel/request-permission,
acp-register-update-handler (inbound session/update via expose). Object params
are string-keyed hash-tables (camelCase; yason encodes HT as objects, plain
lists as arrays — caught via mock fixture bug). Tests: in-CL mock agent over
stdio pipes, 11 checks, 100%. Full suite 2268/2268, lint 607. No ACP schema
SDK adopted — CL owns it, protocolVersion pinned, per design decision.

### Session M9.18: ACP driver built (Wave A2) + CSS planted
**Status**: Built + verified (2026-08-07).
- acp-run-task-on-connection: dispatch driver core over an existing ACP
  connection — initialize, session/new, prompt, capture result (via
  acp-extract-text, which handles ACP content blocks) + observation count;
  register update handler BEFORE the turn (reader would throw on unknown
  inbound method otherwise). fail-closed returns :failed.
- acp-run-task: subprocess wrapper (spawn via uiop:launch-program, connect,
  delegate, teardown). fail-closed: bad command returns :failed, never throws
  (caught by test — launch throws without the handler-case around it).
- Tests: 8 A2/regression (total acp-client 19/19, 100%): driver round-trip,
  fail-closed bad command, camelCase regression, midturn negotiation.
- Full suite 2276/2276, lint 615.
- Note: gave up on a python-subprocess ACP-mock test (stdout-buffering +
  jsonrpc thread race in this env); instead tested the driver core against the
  deterministic in-CL mock over stdio pipes. session/update observation
  counting deferred to subprocess-integration (A2 follow-on).

### Session M9.19: Cost conservation policy + squad-handoff-loop skill
**Status**: Policy captured (2026-08-07).
- Finding from first live ACP squad run: GLM-5.2 ($0.40/M) fired as default
  driver because PM/Designer seats pinned to it as primary; 4x the $0.10/M
  conservation line. Recorded docs/design/cost-conservation.md.
- Policy: >$0.10/M models = strategic reserve, used as infrequently as K3.
  Granular quota windows (weekly/daily/half-day/hour) + reset windows +
  provider balances all budgeted. Squads = one tool among a suite, small on
  average, off-peak when cheaper. Summon-on-need cost ladder (cheap summons
  limited-smart; smart summons cheap for summarization/tagging; procedural
  tools first). User-led vs agentic session tracking = open design item.
- Skill created: squad-handoff-loop (devops) — LAUNCH→RECORD→DESIGN→
  LEAST-CHANGE→RELAUNCH loop; task-card-first, focused seats, background
  launch, verify kick.
- Handoff to user (seat config is user-owned): demote glm-5.2 from PM/Designer
  primary to reserve; default to deepseek-v4-flash-0731. Exact commands in
  session.

### Session M9.20: ACP steering primitive built (Wave A3)
**Status**: Built + verified (2026-08-07).
- acp-steer-command: scored situation (0-1) -> :none/:steer/:interrupt by
  thresholds (default steer>=0.6, interrupt>=0.9); fails closed :none on
  non-number score.
- acp-steer: apply command on live session — :steer => acp-prompt(guidance);
  :interrupt => acp-cancel + acp-prompt(guidance) reprompt. Fail-closed
  (:action :failed). Reuses acp-prompt/acp-cancel/acp-extract-text (A1/A2).
- request_permission human-gate: acp-request-permission already exists (A1),
  reused by gated dispatch.
- Tests: +15 (mapping thresholds incl. >= boundary + non-number fail-closed +
  steer-on-connection + none-noop). acp-client 34/34 (100%).
- Full suite 2291/2291, lint 630. Committed; working tree green.

### Session M9.21: ACP framing fix — newline-delimited JSON-RPC transport
**Status**: Built + interop-verified (2026-08-07).
- CRITICAL finding: cxxxr/jsonrpc's stdio transport uses LSP Content-Length
  framing, but ACP mandates newline-delimited JSON ("messages delimited by
  \\n"). In-repo tests passed only because client+server shared the same
  library framing; a real ACP peer (editor/opencode) would not interoperate.
- Fix: new src/plugins/acp-transport.lisp defining jsonrpc/transport/acp mode
  (acp-transport class) reusing the library's connection/processing/dispatch
  machinery but overriding send/receive to write one JSON line + newline.
  Client (acp-connect-stdio) + server (acp-serve) + test mock all use :mode :acp.
- Verified: acp-client 37/37; test-full 2294/2294; INTEROP PASS — driven
  bin/hngh acp with plain newline-delimited JSON, one line per message, no
  Content-Length headers (python driver /tmp/interop-acp.py). Real-wire-proven.
- Design note folded into agent-client-protocol.md (framing under transport).

### Session M9.22: L2/L3 situation-scoring research + design capture
**Status**: Research + design done (2026-08-07/08).
- Task: design the auto-steering "brain" behind A3 (acp-steer-command).
- Grounded in THREE evidence bases: (1) 243 real human /steer messages mined
  from ~/.hermes/.hermes_history (dominant classes = wasted waits, faulty
  logic, not-sourcing-info, risky-experiment, coordination gaps, cost/token
  overrun, stuck/wedged seats); (2) research delegation -> agent_failure_modes_
  reference.md (23 sources: Huang self-correction, Kamoi survey, MINT, ReAct,
  SWE-agent, GAIA, MAST, tau-bench, hallucination benchmarks); (3) prior-art
  delegation -> B1_agent_supervision_design_space.md (LLaMaGuard/NeMo/Guardrails
  AI/AGT, OTel GenAI, PRM/CriticGPT/Reflexion, OpenFang loop-guard, LangGraph
  HITL). Both refs now in docs/research/.
- Key design decisions: (a) recovery-STAGE progression, not single faults —
  escalate only on 2 consecutive unvalidated same-class faults or S3 or
  long-thinking-zero-env (evidence: intrinsic self-correction of reasoning
  fails; tool-grounded recovery works); (b) weight ACTING stream over THINKING
  stream; (c) Tier-0 procedural detectors first (free, deterministic, catch
  highest-count real cases); (d) judge = cheap/local with calibration; (e)
  progressive gate-lowering log->steer->rewrite->ask->interrupt; (f) open
  taxonomy + self-improvement loop (case-base + review + web re-grounding).
- Deliverable: docs/design/situation-scoring.md (full design capture).
- Note: delegation.max_concurrent_children=1 serialized research (ran 2
  legacy tasks sequentially); considered raising but left as-is per config.

### Session M9.23: Kimi Code quota-reset research (documentation-first)
**Status**: Research done (2026-08-08).
- Question: does the API expose the weekly quota reset time? Answered NO per
  official Kimi Code docs (Membership Benefits): no public endpoint for
  quota/reset; reset is deterministic — every 7 days from subscription date,
  no rollover; rolling 5-hour rate window; console/CLI `/usage` are the
  check surfaces (web only). Balance/token-estimation APIs on api.moonshot.ai
  are the separate pay-as-you-go Open Platform, not kimi-sub.
- Process correction recorded: I probed guessed endpoints before reading the
  docs; the user's standing guidance is documentation-first (authorities over
  experiments). quota-spreader.md now carries the authoritative reset
  semantics + the "model the anchor locally, don't probe" rule.
- Follow-on: if live quota numbers are wanted, read the Kimi Code CLI
  (/usage) source for the real endpoint rather than scraping rendered HTML.

### Session M9.24: L2/L3 situation-detectors + scorer built (Tier-0 + L3)
**Status**: Built + verified (2026-08-08). Attended session (deepseek-v4-flash-0731 via openrouter, Hermes TUI).
- Card 92 waves 1–3 complete. Two new plugins:
  - `src/plugins/situation-detectors.lisp` — **observation model** (plist: ts/agent/kind/tool/args/fingerprint/error-class/tokens/ok/artifacts/seconds; roles :tool-call/:tool-result/:thinking/:wait/:message/:cost-exceeded) + **8 Tier-0 deterministic detectors** (identical-call loop w/ md5 fingerprint + poll-tool exemption, retry-without-progress, zero-progress, long-thinking-token-sink, failing-verification, excessive-waits, cost-exceedance [fail-closed], chatter-loop). Emits `situation.detected` on the event bus (threat.flag-style); never acts.
  - `src/plugins/situation-scoring.lisp` — L3 **scorer + recovery-stage tracker + action mapping**: score = w_i·impact·urgency·spread + w_c·confidence (+0.15/count recurrence boost); recovery-tracker resets on validated fix; progressive gate-lowering lowers steer/interrupt thresholds per unresolved recurrence; maps to A3 via `acp-steer-command`. Fail-closed (nil situation → :none; first-seen never interrupts; S3/token-sink-zero-env → interrupt only on recurrence).
- Wired both into main.lisp lifecycle (init after acp-client, reverse-order shutdown in rollback + stop), packages.lisp, hngh.asd; added both suites to Makefile `test-fast`.
- Tests: test-situation-detectors.lisp 32 checks + test-situation-scoring.lisp 28 checks, each with healthy counter-examples (healthy fix never fires / never interrupts).
- **Verified**: 693/693 fast, 2434/2434 full, exit 0. Baseline before work: 633/633 fast, 2294/2294 full.
- Load-bearing rules honored: never interrupt a single fault with a visible fix; weight ACTING over THINKING (token-sink only fires on runs with no env interaction); fail-closed throughout.
- Docs updated: AGENTS.md, next.md, roadmap.md (status + M-table + design-artifacts row for situation-scoring.md), work-sessions M9.24. Committed. Task 92 → archive to .done/.
- Note (design idea for later): the mission-control/dashboard TUI could render the numeric streams (impact/urgency/spread/confidence, detector hit tables) in the repo's existing Nihei/BLAME! aesthetic as stat-sheet surfaces — presentation-layer follow-on, not built this wave.

### Session M9.25: squad seat startup fix — opencode model-string naming
**Status**: Fixed + verified (2026-08-08). Attended session (deepseek-v4-flash-0731 via openrouter, Hermes TUI).
- Symptom (user-reported): "opencode squad members don't start up." Diagnosed via the headless kick squad-up uses:
  - `opencode run -m deepseek/deepseek-v4-flash-0731` → `UnknownError: Unexpected server error` (seat "starts" — konsole window up, squad-up reports RUNNING — but the first prompt dies on model resolution).
  - `set -a; . ~/.hermes/.env; set +a; opencode run -m openrouter/deepseek/deepseek-v4-flash-0731` → `OPENCODE_SMOKE_OK`.
- Root cause: opencode recognizes the `deepseek` provider but only offers simply-named models there (`deepseek-v4-flash`, `deepseek-v4-pro`); the `-0731` suffix is **openrouter's catalog name**, not a deepseek-provider model. The config's `deepseek/deepseek-v4-flash-0731` never resolved. `deepseek-v4-flash` == `deepseek-v4-flash-0731` (deepseek serves that as its latest under a simpler name). Auth was fine — `OPENROUTER_API_KEY`/`DEEPSEEK_API_KEY` exported in `~/.hermes/.env` (lines 507/496, sourced by the interactive shell, absent from the Hermes terminal env; located by name, never printed).
- Routing decision: we use **Flash** (the smarter model for now) and default to the **openrouter** route because it's usually cheaper — a cost preference, not a rule; `deepseek/deepseek-v4-flash` (direct API) is the valid alternate when it prices lower.
- Fix: `~/.hngh-night/squad-seats.conf` — `SEAT_MODEL[coder]` and `SEAT_MODEL[worker]` → `openrouter/deepseek/deepseek-v4-flash-0731`, with corrected NOTE comments explaining deepseek-provider vs openrouter-catalog naming. `squad-up --list` parses clean.
- Pitfall #27 in the multi-agent-coordination skill corrected: deepseek provider exists but its models are simply named; `-0731` is openrouter's catalog name.
- **Design direction (user)** — squad startup should integrate ACP calls (kick seats over `session/prompt` with a text content block; the durable fix to the paste-race, pitfall #23) while KEEPING the cascading Konsole windows so each seat's session stays visually observable. Recorded in journal 2026-08-08; build is a later wave (agent-client-protocol.md).
- No repo code change in this session; journal + work-sessions entry are the only repo edits.

### Session M9.26: L2/L3 Tier-1 semantic judge built (step 4) + paren lint gate
**Status**: Built + verified (2026-08-08). Attended session (deepseek-v4-flash-0731 via openrouter, Hermes TUI).
- `src/plugins/situation-judge.lisp` — the cheap/local semantic judge:
  - Pluggable backend `:http` (direct OpenAI-compatible chat to ollama/unsloth/vllm, mirrors model-probes curl primitive) with an `:agentic` seam via `*judge-responder*` (one-off opencode/Hermes sessions); responder injection is the test seam too.
  - `build-judge-prompt` — bounded (recent N obs), one-line JSON verdict request; `parse-verdict` fail-closed (only valid score/confidence ranges + known situation keywords; malformed/non-JSON → NIL).
  - `judge-situation` — reserve budget → build → invoke → parse; fail-closed `:error` verdicts (no budget / no response / unparseable) that never escalate.
  - `calibrate-judge` — offline precision/recall/confidence-calibration against a labeled case-base (`calibration` struct; `calibrated` flag only when ≥80% accuracy + ≥70% conf agreement); live gate opens only after calibration is recorded.
- Wired into main.lisp lifecycle, packages.lisp, hngh.asd, Makefile fast suite.
- Tests: test-situation-judge.lisp — 37 checks (prompt bounding, parsing incl. reject-invalid, budget gating, fail-closed paths, calibration perfect/wrong, status shape). Network-free: the dead-endpoint path is simulated by a nil-returning responder (real curl would add ~5s and blow the 15s fast-suite budget).
- **Bugs found + fixed** (recorded in skill sbcl-common-lisp-patterns #13–14):
  - `reserve-judge-call` had `(when judge-budget-ok-p` (missing call parens) → unbound variable at runtime.
  - `parse-verdict` coerces to double-float; tests compared single-float literals (`0.8` ≠ `0.8d0` under `=`).
  - Calibration FP count treated `:none` as truthy — `(not (null :none))` is T; fixed explicit `(eq x :none)` checks.
  - **Symbol collision across test files**: `%obs`/`%call`/`%result` defined in both test-situation-detectors.lisp and test-situation-judge.lisp in the shared `hngh.tests` package — later-loaded copy clobbered the detectors' `%result` (`UNKNOWN-KEYWORD-ARGUMENT :ARTIFACTS`). Renamed judge helpers `%j-*`.
- **`scripts/lint-parens.py` + `make lint-parens`** (user direction): procedural paren guard wired into `test-suite`. Single full-text pass handling strings/comments/char-literals; `--fix` appends missing `)` at EOF. First version false-positived on multi-line docstrings (per-line depth state); rewrote as cross-line string-state pass — **zero false positives on the full tree**, still catches a deliberately-broken fixture.
- **Verified**: 730/730 fast (lint-parens gate runs first, exit 0, 4.5s < 15s budget), 2471/2471 full, exit 0. Baseline before work: 693/693 fast, 2434/2434 full.
- MisakaNet lesson candidates for the paren/docstring/CL-test gotchas added to backlog (submission free; search free; lesson reading is the paid side — noted correctly).
- Docs updated: AGENTS.md, next.md, roadmap.md (status + design-artifacts row), CHANGELOG, backlog, work-sessions M9.26. Committed.

### Session M9.27: L2/L3 persistent case-base + review pass (step 5)
**Status**: Built + verified (2026-08-08). Attended session (deepseek-v4-flash-0731 via openrouter, Hermes TUI).
- `src/plugins/situation-casebase.lisp` — the self-improvement substrate:
  - **Persistent case-base** via the state-store journal (`append-journal`/`read-journal`): every scored situation + action + outcome appended, with monotonic ids, timestamps, source (`:auto`/`:human`), and attribution (§7). Human `/steer` is recorded high-weight as ground-truth (§7.5).
  - **Review pass** (`run-review-pass`): cheap/local, offline re-run of the judge against the case-base; recomputes precision/recall/conf-agreement, appends a pass record to pass-stats. `accuracy-improving-p` is the §8 step 5 gate (calibration improves across successive passes). `emergent-classes` is an open-taxonomy probe — new classes are expected, surfaced for human triage.
- Wired into main.lisp lifecycle, packages.lisp, hngh.asd, Makefile fast suite.
- Tests: test-situation-casebase.lisp — 25 checks (persistence/read-back, monotonic ids, human high-weight, distribution, review metrics, improvement gate, empty-base noop, emergent probe, status shape). Uses a temp isolated hngh-home + a deterministic judge hook — **no network, no model**.
- **Bugs found + fixed**: `record-case` malformed lambda list (`&rest args &key :score` rejected the `:score` keyword); `run-review-pass`'s default `responsibility` was `identity` comparing the whole verdict plist to a keyword (fixed to extract `:situation`); `accuracy-improving-p` used `(second (last ...))` wrongly (fixed with index math); my record-ids test assertion was wrong.
- **Verified**: 755/755 fast (lint-parens gate first), 2496/2496 full, exit 0. Baseline before work: 730/730 fast, 2471/2471 full.
- Docs updated: AGENTS.md, next.md (step 5 done, step 6 P0), roadmap.md (status + design-artifacts row), CHANGELOG, work-sessions M9.27. Committed + pushed.

### Session M9.28: M8 model-routing data seed + two-role split
**Status**: Built + verified (2026-08-08). Attended session (deepseek-v4-flash-0731 via openrouter, Hermes TUI).
- Per the 2026-08 human steer: **agentic model = deepseek-v4-flash; coding model = gpt-5.6-luna**. Landed as the M8 routing *data seed* (`src/plugins/model-routes.lisp`) per `docs/design/model-routing.md` verification task #2 — the route table (id/backend/model/price/class) as data, plus the two-role primary split, with `route-model`/`role-model` accessors (unknown role falls back to agentic primary).
- Read-only parse test: test-model-routes.lisp — 63 checks (route fields well-formed, known routes present, two-role primaries correct, backstop).
- **Suspended deliberately**: C6 `--emit` from cron, which I had started toward — user steered toward the higher-value simpler route split instead. Full M8 routers (`route-task`) remain unbuilt, by design (seed data only).
- **Verified**: 818/818 fast (was 755), full suite running. Baseline: 755/755 fast, 2496/2496 full.
- Docs updated: AGENTS.md, next.md (M8 seed done, added to Up Next as P1), roadmap.md (status + design-artifacts row), CHANGELOG, work-sessions M9.28. Committed + pushed.

### Session M9.29: Wave B governance guardrails (`make lint-deps`) — park C6
**Status**: Built + verified (2026-08-08). Attended session (deepseek-v4-flash-0731 via openrouter, Hermes TUI).
- **Owner direction**: build security + guardrails BEFORE public release and BEFORE launching automatic sessions — "the most rational, stable, known-reliable route." C6 emit-cron (launch automatic Hngh sessions) deliberately PARKED; the design's own gate (autonomy-strategy §7 Wave B/C before self-modification of core) supports this ordering.
- `scripts/lint-deps.py` — deterministic Wave B fitness checks, same pattern as lint-parens (single full-tree pass, exit 1 on violations), wired into `test-suite` (`make test` = lint-parens → lint-deps → 818 tests):
  - **rule1**: no plugin→plugin `:use` (plugins talk via hngh.core — verified: zero such clauses in the real tree)
  - **rule2**: core packages never call plugin symbols (main.lisp = composition root, restricted to `:init`/`:shutdown` — the registration contract)
  - **rule3**: no circular deps over the `:use` + plugin-call graph
  - **rule4**: production never depends on `hngh.tests`
- **Fixture-verified**: 4 deliberate-violation fixtures under `tests/fixtures/guardrails/` all fire (each rule); real tree clean. Proof the checker isn't a no-op.
- **Bugs found + fixed during build**: (a) `_USE_RE` expected nested `:use (...)` but repo writes `(:use :cl ...)` — fixed `\(?`; (b) rule2 was directory-based (src/core/) but core-ness is package-based (hngh.core.* / hngh) — fixed; (c) multi-in-package files misattributed calls — added `segment_packages` (last-in-package scoping); (d) **cycle finder never fired**: call edges captured bare plugin name (`circ-a`) while graph keys are full packages (`hngh.plugins.circ-a`) — the classic name-mismatch cycle bug, edges normalized to full names.
- **Verified**: `make test` exit 0 — both gates before tests, 818/818 fast, 0 fail-suites.
- Docs updated: CHANGELOG, work-sessions M9.29. Committed + pushed.

### Session M9.30: Wave C immutable safety layer (part 1)
**Status**: Built + verified (2026-08-08). Attended session (deepseek-v4-flash-0731 via openrouter, Hermes TUI).
- **Owner direction**: continue security/guardrails before anything public or self-launched. Wave C begins with its root: the **immutable safety layer**.
- `src/core/safety-boundary.lisp` (CORE, not a plugin — so the agent can't edit its own protection list):
  - Registry: config/hngh.lisp + config/sentry.lisp + config/sandbox.lisp frozen at init; containment check (anything under a protected dir is protected).
  - `allow-mutation-p` fail-closed; denial journaled to the append-only `journal/actions.lisp`. `ensure-mutable` signals.
  - Best-effort 0444 mode-lock (temp-dir/read-only tolerant; in-process guard always enforces).
  - Wired after state-store, before plugins (so configs are locked before any plugin runs); on both shutdown paths.
- Tests: test-safety-boundary.lisp — 19 checks (registry frozen, containment, deny+log, allow no-log, ensure-mutable signals, log shape, status). Isolated temp home; no network/model/privileges.
- Verified uiop functions against SBCL before using (`subpathp`, `pathname-equal`, `pathname-directory-pathname`, `file-exists-p` all present) — no guessed APIs.
- **Verified**: 837/837 fast (was 818), full suite running; exit 0.
- Docs updated: next.md (Wave C P0 part 1 shipped), CHANGELOG (+19 checks). Committed + pushed.
- Also: verified the Hermes **file-mutation verifier footer** explanation for the user — AGENTS.md flagged as "not modified" was a false positive from repairing a failed patch via `sed` (invisible to the verifier); file was correct. Owner README.md revision committed (`8e2433f`) with attribution.

### Session M9.31: Wave C open-source adoption research
**Status**: Research + decision doc committed (2026-08-08). Attended session (deepseek-v4-flash-0731 via openrouter, Hermes TUI).
- **Owner directive**: don't reinvent — take advantage of existing OSS tools, libraries, methods; research options where sensible.
- `docs/research/wave-c-open-source-tooling.md` — maps all 8 Wave C items to ADOPT-or-BUILD decisions with sources:
  - **ADOPT**: OPA (least-agency tool scoping, CNCF policy engine), Bubblewrap (per-task sandbox — unprivileged, smallest trust base; Firejail's own maintainers caution its SUID wrapper), qlot (CL dep pinning), Canarytokens (self-hosted canary server, no Docker), LLM Guard sidecar (untrusted-content scan).
  - **BUILD (genuinely novel)**: provenance tagging (our attribution ledger), `:operation` human gate extension (core commits + dep installs).
  - **Small build with precedent**: SHA-256 hash-chained action log — direct precedent is NousResearch/hermes-agent issue #487 (same pattern, OpenFang-inspired); Trillian assessed and rejected (over-heavy).
  - gVisor/Firecracker/Kata assessed + deferred (hardened fleet, not single host now).
- Verified against authoritative sources (kernel.org Landlock docs, OPA docs, Thinkst, NeMo Guardrails GitHub, qlot/CLPM, hermes-agent #487) — no guessed claims; every decision cited.
- Adoption order documented (qlot → bwrap → OPA → hash-chain → canaries/scan → `:operation` gate); Wave C gate unchanged.
- Docs updated: next.md (Wave C row: research done), roadmap.md (design-artifacts row). Committed + pushed.

### Session M9.32: Owner review — OPA shelved, Syncthing flagship, backup accommodation
**Status**: Design + ADRs + docs committed (2026-08-08). Attended session (deepseek-v4-flash-0731 via openrouter, Hermes TUI).
- **Owner review of the Wave C adoption doc**: agreed to shelf **OPA** (single-host ~15 immutable CL rules; Rego subprocess + a policy language for the agent to maintain costs more than it buys — ADR-044).
- **Owner direction — backup**: Hngh should manage/configure/optimize backup + sync across many devices, eliminating manual config; accommodate remote + local-network + device-local options. **Syncthing flagship**: P2P, no server, REST API at localhost:8384 = a management surface Hngh steers (observe → reconcile → tune), `:operation`-gated, read-only fail-closed default. Owner clarifications: **gbd is a dotfile VCS, not a general backup manager**; the existing plugin is the Hngh-state-tree git backup — so the design is a **three-job split** (gbd dotfiles / backup-manager state / Syncthing mirror), not one tool.
- `docs/design/backup-sync-integration.md` written; **ADR-043** (Syncthing + split, restic/borg deferred), **ADR-044** (OPA shelved) appended to decisions.md; research doc's OPA row + additions updated; next.md (P1 backup/sync row), roadmap.md (design-artifacts row), CHANGELOG done.
- Phase A of the design (observe/status + Tier-0 out-of-sync detector, fixture-tested, no live instance) is the next concrete build when greenlit.
- Docs updated; committed + pushed.

### Session M9.33: Task deck 93–99 + Luna delegation verified
**Status**: Deck composed + delivery verified (2026-08-08). Attended session (deepseek-v4-flash-0731 via openrouter, Hermes TUI).
- **Owner directive**: compose plans/designs → requirements → granular task cards for continual dogfooding to cheaper agents; session estimates provisional until work is scaffolded onto surfaces.
- **Delegation verified**: `gpt-5.6-luna` and `gpt-5.6-luna-max` both answer live through the **openai provider** with the existing `OPENAI_API_KEY` (probe exit 0, "LUNA_OK" / "LUNA_MAX_OK") — no Copilot OAuth, no install; the doc caveat about Copilot device-flow does not apply to this route. Delegated code completions on Luna are available per-card.
- **Cards 93–99** written to `~/.hngh-night/tasks/` (each with context, VERIFIED FACTS, Do/MUST DO/MUST NOT DO, verification gate, attribution):
  - 93 qlot pin (Wave C item 1, gate) → 94 hash-chain action log (item 4, gate) → 96 bwrap sandbox (item 2, gate) → 97 native least-agency scoping (item 3, gate — no OPA per ADR-044).
  - 95 backup/sync Phase A observe (Syncthing REST status + Tier-0 detector, fixture-tested) — P1, sequenced alongside.
  - 98 canary/scan sidecar (item 5, external services), 99 `:operation` gate extension (item 8) — tail after gate items.
- next.md launch-context block updated with the deck + delegation availability. Docs committed + pushed.

### Session M9.34: Task 93 (qlot pin) + CI red→green
**Status**: Delivered + verified (2026-08-09). Attended session (deepseek-v4-flash-0731 via openrouter, Hermes TUI).
- **Owner report**: GitHub "Run failed" emails on every push. Investigated `.github/workflows/`:
  - `ci.yml` build step always failed — runner had SBCL but **no Quicklisp**, so `asdf:load-system :hngh` died on `:BORDEAUX-THREADS not found`. Failing on every push (not a this-week regression).
  - `mirror.yml` failed on SSH push (runner has no `~/.ssh/id_ed25519_codeberg`) AND is redundant — local already pushes both remotes (`codeberg` remote + origin→both). It spawned the "Run failed" email noise.
- **Fix (task 93 + CI, aligned with Wave C, not a quicklisp hack)**: installed **qlot 1.8.4** (user-space `~/.local/bin`, non-privileged — owner consented); wrote `qlfile` + generated `qlfile.lock` (pins **Quicklisp dist 2026-01-01** + 8 project deps: bordeaux-threads, cl-ppcre, babel, jsonrpc, alexandria, yason, jsown, fiveam; sb-posix/sb-bsd-sockets are SBCL-internal, correctly excluded). Makefile `SBCL_FLAGS` now loads `.qlot/setup.lisp` when present (conditional no-op otherwise); `.qlot/` gitignored.
- **CI decision (owner, 2026-08-09)**: after diagnosing the long-failing build CI and deleting the spam `mirror.yml`, the per-push **build/test CI was dropped** — the local `make test` gate (lint-parens + lint-deps + 837 checks) is the quality source of truth and runs on every commit; server CI became **lint-only** (deterministic parens + dependency guardrails, pure python, seconds) as a future public health signal. Green on GitHub. Known CI-timing flake in AN ACP SUBPROCESS-PIPE TEST (`APPLY-SIGNAL-PAUSE-MAPS-TO-DISPATCH` — SIMPLE-STREAM-ERROR, fd read race) — passes locally; flagged as a genuine bug to fix (new task), no longer CI-blocking.
- **Verified under the pin** (real output): `make test` exit 0, **837/837 fast, 0 fail-suites**, guardrails clean; `make build` exit 0 (53MB `bin/hngh`).
- Docs: next.md (shipped block + Wave C row item 1 DONE), CHANGELOG, work-sessions. Task card 93 archived to `.done/`.
