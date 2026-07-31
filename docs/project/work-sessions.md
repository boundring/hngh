# Hngh Work Session Plan

**Status**: M1 batches 0–4 complete; Batch 5 next
**Last updated**: 2026-06-24

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