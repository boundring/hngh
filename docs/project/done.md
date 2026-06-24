# Done — Completed Work Log

**Last updated**: 2026-06-24

---

## 2026-06-22

### Design Phase Complete (Phases 1–5)
- **Phase 1**: Requirements crystallization — 5 Q&A rounds, scope locked
- **Phase 2**: Architecture pattern selection — Image + Bus + Supervisor
- **Phase 3**: Component decomposition — 21 components specified
- **Phase 4**: Integration & data flow — 4 integration layers, 8 sequence diagrams
- **Phase 5**: Design specification — single source of truth compiled
- **Artifacts**: `docs/design/architecture-decision-record.md`, `docs/design/components.md`, `docs/design/integrations.md`, `docs/design/hngh-design-spec.md`

### Session 0A: Repo Setup + Project Management
- Reinitialized GitHub repo (boundring/hngh) — wiped prior shell/Python project
- Pushed to Codeberg mirror (hngh/hngh)
- Created repo structure: README, LICENSE (AGPL-3.0), .gitignore, CONTRIBUTING, issue templates
- Copied 4 design artifacts to `docs/design/`
- Created project management docs: `roadmap.md`, `work-sessions.md`
- GitHub milestones created: M0 Foundation, M1 The Harness, M2 The Companion, M3 The Network
- GitHub labels created: design, core, plugin, system-daemon, security, ai, packaging, ci, documentation, project-mgmt
- 11 issues created: M0.1–M0.10 + Session 0B build system
- GitHub Project board created (Hngh Development) with custom fields: Status, Priority, Phase, Size
- All 11 issues linked to project board
- Planning docs added: next.md, done.md, backlog.md, decisions.md

### Session 0B: Build System + CI Scaffolding
- Created ASDF system definition (`hngh.asd`) with core + tests systems
- Created package definitions for all core components (event-bus, state-store, plugin-host, supervisor, scheduler, threat-detection)
- Created entry point (`src/core/main.lisp`) with start/stop/main, --version, --help, --hngh-home
- Created custom test harness (`tests/unit/harness.lisp`) with define-test, assert-true, assert-equal, assert-condition
- Created Makefile with targets: all, build, daemon, run, test, repl, install, uninstall, clean, help
- Created system daemon C skeleton (`src/system-daemon/main.c`) with dbus connection
- Created system daemon Makefile
- Updated CI workflow to build SBCL and run tests
- Created directory structure: `src/core/`, `src/plugins/`, `src/system-daemon/`, `tests/unit/`, `tests/integration/`, `tests/fixtures/`
- Verified: `make build` produces 37MB standalone binary; `./bin/hngh --version` outputs "hngh 0.0.1"; `make test` runs (0/0 — no tests defined yet); exit code 0

### Session M0.1: SBCL Project Skeleton
- Created `src/core/logging.lisp` — log levels (:debug/:info/:warn/:error) with priority filtering and ISO 8601 timestamps
- Created `src/core/config.lisp` — config file loading, merge with defaults, config-get/set/save
- Rewrote `src/core/main.lisp` — proper init sequence (state tree → config → log level → signal handlers), 17-directory state tree creation, SIGTERM/SIGINT handling, --log-level CLI option
- Created `tests/unit/test-main.lisp` — 12 unit tests (version, log levels, config, start/stop, state tree init, keyword/option parsing)
- Updated ASDF system and package exports
- Verified: `make build` produces binary; `make test` = 12/12 passed, 0 failed; `./bin/hngh --log-level debug` shows DEBUG messages

### Sessions M0.2 + M0.3: Event Bus + State Store
- Created `src/core/event-bus.lisp` — pub/sub with topic matching (exact, wildcard `.*` and `*`), event journaling (append-only to `journal/events/YYYY-MM-DD.lisp`), persistent subscriptions (replay from journal), subscription filters, backpressure policies (:block, :drop, :queue)
- Created `src/core/state-store.lisp` — file tree read/write (Lisp data and raw strings), journal append/read, file-based cross-plugin locks with TTL and holder tracking, snapshot (tree hash), automatic stale lock reclamation, shutdown releases all locks
- Created `tests/unit/test-event-bus.lisp` — 11 tests: topic matching (4), bus lifecycle (1), publish/subscribe (4), journaling (2)
- Created `tests/unit/test-state-store.lisp` — 17 tests: lifecycle (1), file r/w (6), journal (1), locks (8), snapshot (2) [one test uses sleep for TTL expiry]
- Wired both into start/stop sequence in main.lisp
- Updated hngh.asd and packages.lisp
- Verified: `make build` produces 37MB binary; `make test` = **40/40 passed, 0 failed**

### Sessions M0.4 + M0.5 + M0.6: Plugin Host + Supervisor + Scheduler
- Created `src/core/plugin-host.lisp` — manifest parsing, CL plugin loading (ASDF or file), package-level isolation, init/cleanup/reload function resolution, load/unload/reload/list/query
- Created `src/core/supervisor.lisp` — component registration, restart policies (:always/:on-failure/:never), health checks, restart window tracking, max-restarts escalation, event publishing on restart/escalate
- Created `src/core/scheduler.lisp` — background thread scheduler, interval/delayed/at schedules, event publishing and function calling, cancel/list, thread-safe
- Created `tests/fixtures/test-plugin/` — minimal first-party CL test plugin with init/cleanup/reload/get-state/set-state
- Created `tests/unit/test-plugin-host.lisp` — 11 tests (manifest parsing, validation, load/unload/reload, query)
- Created `tests/unit/test-supervisor.lisp` — 11 tests (lifecycle, registration, health checks, restart logic, escalation, query)
- Created `tests/unit/test-scheduler.lisp` — 6 tests (lifecycle, delayed/interval firing, cancel, event publishing, list)
- Wired all three into start/stop sequence in main.lisp
- Updated hngh.asd and packages.lisp
- Verified: `make build` produces binary; `make test` = **69/69 passed, 0 failed**

### Sessions M0.7 + M0.8 + M0.9: dbus Bridge + Dashboard TUI + System Daemon
- Created `src/plugins/dbus-bridge.lisp` (B13) — gdbus monitor subprocess for session bus signals, gdbus call for method invocation, background reader thread, signal translation stub
- Created `src/plugins/dashboard-tui.lisp` (B9) — raw ANSI escape codes (no external TUI dep), three views (overview/events/plugins), wildcard event subscription (capped at 100), headless mode, background input thread
- Rewrote `src/system-daemon/main.c` (C1) — full dbus method handlers: InstallPackages (validates package names, spawns pacman), WriteFile (path whitelist, byte array content), CreateSnapshot (btrfs). Added `_POSIX_C_SOURCE` for popen/pclose/chmod
- Created systemd units: `hngh-system.service`, `hngh-helper@.service`, `org.hngh.System.conf` (dbus policy)
- Created `systemd/user/hngh.service` — user daemon systemd unit
- Created `tests/unit/test-dbus-bridge.lisp` — 3 tests, `tests/unit/test-dashboard-tui.lisp` — 6 tests
- Wired dbus bridge and dashboard TUI into start/stop sequence
- Verified: `make test` = **78/78 passed, 0 failed**

### Session M0.10: End-to-End Integration (commit b89abc7)
- Created `tests/integration/m0-full-stack.sh` — 18 integration tests covering build, version, help, state tree (8 dirs), event journal, unit tests, system daemon compilation, config
- Added `integration-test` target to Makefile
- Created `systemd/user/hngh.service` — user daemon systemd unit
- Fixed: C daemon needed `_POSIX_C_SOURCE 200809L` for popen/pclose/chmod with `-std=c11`
- Fixed: Event journal test checks directory existence (no events published during stub startup, so no journal file is created)
- Verified: `make integration-test` = 18/18 passed, 0 failed
- Full stack validated: build → version → help → state tree (8 dirs) → event journal dir → unit tests (78/78) → system daemon compiles → config file writable

---

## 2026-06-23

### Session M1.0a: Migrate test suite to FiveAM (commit 8ebcbe4)
- Migrated all 78 M0 unit tests from custom harness to FiveAM
  (`def-suite`/`in-suite`/`test`/`is`/`signals`/`is-true`/`is-equal`)
- Centralised test fixture helpers (`make-tmp-home`, `cleanup-tmp-home`,
  `fixture-path`) in `tests/unit/packages.lisp`
- D-013 closed: test suite is now on FiveAM, no functional regressions
- Verified: `make test` = 78/78 passed, 0 failed (after migration)

### Sessions M1.1 + M1.2: Procedural threat detection + Resource manager (commit f33bbd6)
- **M1.1 — Procedural Threat Detection (A7)**: L1 static analysis
  (manifest validation, dangerous function detection, capability cross-
  check, pattern DB, trust-tier rules with mandatory L2 review for
  AI-generated). L3 runtime observation via `plugin.*` and `secret.*`
  event subscriptions. Pattern DB persistence. `threat.flag` events.
  19 FiveAM tests, all passing.
- **M1.2 — Resource Manager (A4)**: hardware audit (lspci,
  /proc/cpuinfo, /proc/meminfo), VRAM arbitration with priority-based
  preemption, `:cpu-affinity`/`:memory`/`:model-load` stubs, pressure
  monitoring (`:normal`/`:elevated`/`:critical`), event publication.
  17 FiveAM tests, all passing.
- Wired both into start/stop sequence in `src/core/main.lisp`.
- Updated `hngh.asd` and `packages.lisp`.
- Verified: `make test` = 78 (M0) + 36 (M1.1+M1.2) = **114/114 passed, 0 failed**

### Sessions M1.3 + M1.4 + M1.11: Package manager + System config + Secrets manager (commit f45c5c7)
- **M1.3 — Package Manager (B1)**: pacman queries (search, info, list,
  updates, orphans), AUR helper detection (paru preferred), privileged
  install via dbus, breakage detection. 15 FiveAM tests.
- **M1.4 — System Config (B2)**: read direct (`/etc/`, `~/.config/`),
  write via daemon (`/etc/`, `/usr/`) or direct (`~/.config/`),
  btrfs snapshot via daemon, managed-paths list with persistence.
  14 FiveAM tests.
- **M1.11 — Secrets Manager (B8)**: local-vault backend, policy-
  checked access, 4 backends (1Password / KeePassXC / vault.age /
  local-vault) with only local-vault fully implemented in M1.
  Access log never contains values. 22 FiveAM tests.
- Wired all three into start/stop sequence in `src/core/main.lisp`.
- Verified: `make test` = 78 (M0) + 36 (M1.1+M1.2) + 51 (M1.3+M1.4+M1.11) = **165/165 passed, 0 failed**

---

## 2026-06-24

### Sessions M1.5 + M1.6 + M1.7: Model runtime + AI tool hub + AI orchestrator (commit 868de1a)
- **M1.5 — Model Runtime Manager (B4)**: runtime discovery (ollama,
  llama.cpp, comfyui, unsloth), spawn (ollama loads model on shared
  server, llama.cpp subprocess), stop (unload model / SIGTERM),
  health check (curl), resource integration (subscribe to
  `resource.preempted` and `resource.pressure`), supervisor
  integration. 13 FiveAM tests.
- **M1.6 — AI Tool Hub (B11)**: tool registry (8 default tools,
  capability/cost metadata), tool detection at init, invoke (agentic
  CLI subprocess + direct API via curl), API keys from Secrets
  Manager (env vars, never cmdline), select-tool (capability →
  availability → privacy → cost → prefer-agentic), cost tracking.
  17 FiveAM tests.
- **M1.7 — AI Orchestrator (B3)**: delegate (meta-context → select
  tier → route → emit events → persist transcript), meta-context
  (system state, recent activity, KB articles), handoff, kill-agent,
  policy management, resource pressure handling. 16 FiveAM tests.
- Wired all three into start/stop sequence in `src/core/main.lisp`.
- Verified: `make test` = 165 + 46 = **211/211 passed, 0 failed**

### Session: Harden M1.5 + M1.6 + M1.7 orchestration (commit 905ea2f)
- Added curl connect/max timeouts across model-runtime health/probe/unload
- Routed preemption through `stop-runtime` with `:reason :preempted`
- Emitted canonical `:id` in agent.spawned/completed/failed payloads
- Used provider-specific auth headers (Anthropic: `x-api-key`, Google:
  `x-goog-api-key`, OpenAI: `Authorization: Bearer`)
- Moved direct-API request payload + headers to temp files
- Orchestrator tracks `backend-id` and maps completion by either
  agent ID or invocation/backend ID
- Policy `max-cost` and `privacy` now flow into `select-tool`
- Local invoke passes proper model-spec plist
- 3 new regression tests: invocation-id mapping, runtime preemption
  delegation, provider-API headers
- Integration help-flag grep tightened to fixed-string matching
- Verified: `make test && make integration-test` = **1018 unit + 18 integration, all passing**

### Sessions M1.8 + M1.9 + M1.12: LLM threat detector + Hnghbeats + Knowledge base (commit cc4afa8)
- **M1.8 — LLM Threat Detector (B5)**: L2 plugin review (`review-plugin`)
  and L4 behaviour assessment (`review-behavior`), scheduler-driven
  periodic reviews (`run-periodic-reviews`), `threat.flag` event
  subscription triggering immediate L4 review, persistence to
  `config/plugins/llm-threat/prefs.lisp`, `state/plugins/llm-threat/history.lisp`,
  `plugins/<slug>/review-verdict.lisp`, and `state/plugin-observations/<slug>/assessments.lisp`,
  resource grant integration (`:model-load`), `threat.review-verdict` and
  `threat.assessment` events, KB pattern recording for suspicious/malicious
  assessments. 6 FiveAM tests.
- **M1.9 — Hnghbeats (B6)**: daily condensation with deterministic
  summaries (categories: `:system-changes`, `:package-ops`,
  `:agent-activity`, `:costs`, `:threat-events`, `:user-activity`,
  `:errors`), persistence to `journal/hnghbeats/YYYY-MM-DD.lisp`,
  `hnghbeats.beat` event emission. 3 FiveAM tests.
- **M1.12 — Knowledge Base (B12)**: article/decision/pattern storage,
  keyword + tag query, lock-aware writes (returns NIL if another holder
  has the lock), persistent across restart. 7 FiveAM tests.
- Wired all three into start/stop sequence in `src/core/main.lisp`
  (with rollback on failure and reverse-order shutdown).
- Added LLM threat detector state dirs to `*state-tree-dirs*`.
- Verified: `make test && make integration-test` = **1020 unit + 18 integration, all passing**

### Session M1.10: Backup Manager (B7) — Batch 5 (pending commit)
- **M1.10 — Backup Manager (B7)**: git-versions the `~/.hngh/` state tree.
  Public API: `init`, `shutdown`, `running-p`, `status`, `commit`,
  `push-backup`, `restore`, `diff`, `list-history`, `add-remote`,
  `list-remotes`, `managed-ignore-paths`.
  - Idempotent `git init`; managed `.gitignore` (defaults + persisted user ignores).
  - SECURITY: secrets never committed — defense-in-depth via `.gitignore` +
    a pre-commit staging guard (`enforce-staging-guard`) that unstages
    forbidden paths (`secrets/`, `state/locks/`, `config/plugins/secrets-manager/`,
    `*.age`, `*.gpg`) and aborts the commit.
  - Periodic auto-commit via Scheduler; `config.changed` subscription
    refreshes `.gitignore`/remotes.
  - Events: `backup.committed`, `backup.pushed`, `backup.restored`.
  - Owned state: `config/plugins/backup-manager/{remotes,ignore}.lisp`,
    `state/plugins/backup-manager/history.lisp`.
- **Oracle security review** performed before finalizing. 5 HIGH findings
  fixed (all with regression tests):
  - **H1**: git C-quoting of non-ASCII paths defeated the prefix guard →
    added `unquote-git-path`, applied in `staged-files`.
  - **H2**: argument injection (option-like values) → `safe-git-arg-p`
    validation + `--` separators in restore/push-backup/add-remote.
  - **H3**: TOCTOU race between guard check and commit (scheduler thread vs
    user) → `*git-lock*` mutex (bordeaux-threads) wrapping
    commit/push-backup/restore; periodic lambda calls `commit` (no double-lock).
  - **H4**: restore clobbered the working tree → auto-stash
    (`--include-untracked`) before checkout; `:stashed` in payload.
  - **H5**: restore could extract secrets from history → forbidden-path
    rejection before any stash/checkout.
  - **M3**: guard now unstages ONLY violating paths (`git reset -- <paths>`).
  - Documented limitations: prior-committed secrets persist in history (M1);
    case-sensitive-FS assumption (M2). See decisions.md D-028/D-029.
- Wired into start/stop sequence in `src/core/main.lisp` (init after
  secrets-manager; reverse-order shutdown; state-tree dirs added).
- 16 FiveAM tests (8 functional + 8 security-fix regression tests).
- Verified: `make test && make integration-test` = **1090 FiveAM checks
  (243 unit test functions) + 18 integration, all passing**

---

## Milestone 0 Summary (complete)

All 11 sessions completed. 96 total tests (78 unit + 18 integration), all passing.

### Components built (7 core + 2 plugins + 1 external):

| Component | ID | File | Tests |
|---|---|---|---|
| Logging | — | src/core/logging.lisp | 4 (in test-main) |
| Config | — | src/core/config.lisp | 4 (in test-main) |
| Main entry | — | src/core/main.lisp | 4 (in test-main) |
| Event Bus | A2 | src/core/event-bus.lisp | 11 |
| State Store | A3 | src/core/state-store.lisp | 17 |
| Plugin Host | A1 | src/core/plugin-host.lisp | 11 |
| Supervisor | A6 | src/core/supervisor.lisp | 11 |
| Scheduler | A5 | src/core/scheduler.lisp | 6 |
| dbus Bridge | B13 | src/plugins/dbus-bridge.lisp | 3 |
| Dashboard TUI | B9 | src/plugins/dashboard-tui.lisp | 6 |
| System Daemon | C1 | src/system-daemon/main.c | (integration) |

### Decisions logged (D-005 through D-009):
- D-005: Custom test harness (FiveAM deferred) — **superseded by D-013 in M1.0a**
- D-006: Build dir named bin/ (Makefile conflict avoidance)
- D-007: File-based locks (SQLite deferred)
- D-008: Plugin manifests use Lisp plist (YAML deferred)
- D-009: Scheduler action functions as objects (not quoted forms)

### Build system:
- ASDF system definition (hngh.asd) with core + tests systems
- Makefile: all, build, daemon, run, test, integration-test, repl, install, uninstall, clean, help
- CI: GitHub Actions (ci.yml), Codeberg mirror (mirror.yml)
- systemd units: hngh-system.service, hngh-helper@.service, hngh.service (user), org.hngh.System.conf (dbus policy)

---

## Milestone 1 Status (in progress)

Batches 0–4 complete; Batch 5 in progress — **M1.10 (Backup Manager) done** (2026-06-24).
Batch 5 remaining: M1.13 KDE, M1.14 PKGBUILD, M1.15 integration tests.

**Total tests after M1.10**: 243 unit + 18 integration = 261, all passing (1090 FiveAM checks).

### Components added by M1:

| Component | ID | File | Tests | Status |
|---|---|---|---|---|
| Procedural threat detection (core) | A7 | src/core/threat-detection.lisp | 19 | Done (M1.1) |
| Resource manager (core) | A4 | src/core/resource-manager.lisp | 17 | Done (M1.2) |
| Package manager | B1 | src/plugins/package-manager.lisp | 15 | Done (M1.3) |
| System config | B2 | src/plugins/system-config.lisp | 14 | Done (M1.4) |
| Model runtime manager | B4 | src/plugins/model-runtime.lisp | 13 | Done (M1.5) |
| AI tool hub | B11 | src/plugins/ai-tool-hub.lisp | 17 | Done (M1.6) |
| AI orchestrator | B3 | src/plugins/ai-orchestrator.lisp | 16 | Done (M1.7) |
| LLM threat detector | B5 | src/plugins/llm-threat-detector.lisp | 6 | Done (M1.8) |
| Hnghbeats | B6 | src/plugins/hnghbeats.lisp | 3 | Done (M1.9) |
| Secrets manager | B8 | src/plugins/secrets-manager.lisp | 22 | Done (M1.11) |
| Knowledge base | B12 | src/plugins/knowledge-base.lisp | 7 | Done (M1.12) |
| Backup manager | B7 | src/plugins/backup-manager.lisp | 16 | Done (M1.10) |
| KDE integration | B10 | — | — | Future (M1.13, optional) |
| PKGBUILD + packages | — | — | — | Future (M1.14) |
| Integration tests (M1) | — | — | — | Future (M1.15) |
