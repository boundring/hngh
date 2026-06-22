# Done — Completed Work Log

**Last updated**: 2026-06-22

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
- Created `systemd/user/hngh.service` — user daemon unit
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
- D-005: Custom test harness (FiveAM deferred)
- D-006: Build dir named bin/ (Makefile conflict avoidance)
- D-007: File-based locks (SQLite deferred)
- D-008: Plugin manifests use Lisp plist (YAML deferred)
- D-009: Scheduler action functions as objects (not quoted forms)

### Build system:
- ASDF system definition (hngh.asd) with core + tests systems
- Makefile: all, build, daemon, run, test, integration-test, repl, install, uninstall, clean, help
- CI: GitHub Actions (ci.yml), Codeberg mirror (mirror.yml)
- systemd units: hngh-system.service, hngh-helper@.service, hngh.service (user), org.hngh.System.conf (dbus policy)
- Created `tests/integration/m0-full-stack.sh` — 18 integration tests covering build, version, help, state tree (8 dirs), event journal, unit tests, system daemon compilation, config
- Added `integration-test` target to Makefile
- Fixed: C daemon needed `_POSIX_C_SOURCE 200809L` for popen/pclose/chmod with `-std=c11`
- Fixed: Event journal test checks directory existence (no events published during stub startup)
- Verified: `make integration-test` = **18/18 passed, 0 failed**
- Full stack: build → version → help → state tree → event journal → unit tests → system daemon → config — all pass