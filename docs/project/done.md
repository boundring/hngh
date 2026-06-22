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