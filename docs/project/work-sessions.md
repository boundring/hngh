# Hngh Work Session Plan

**Status**: Planning
**Last updated**: 2026-06-22

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

## Pre-Implementation Sessions

### Session 0A: Repo Setup + Project Management
**Goal**: Reinitialize repos, set up project management scaffolding.
**Artifacts**: README, LICENSE, .gitignore, design artifacts in repo, GitHub milestones/issues/project board.
**Exit criteria**: Both remotes have the new repo; GitHub has milestones M0–M3 with issues; project board configured.
**Dependencies**: Design spec complete (done).
**Status**: In progress.

### Session 0B: Build System + CI Scaffolding
**Goal**: Set up ASDF system definition for the SBCL project, Makefile, CI workflow stub.
**Artifacts**: `hngh.asd` (ASDF system), `Makefile`, `.github/workflows/ci.yml` (stub), `src/` directory structure.
**Exit criteria**: `make build` produces an SBCL image (even if empty); CI runs on push.
**Dependencies**: Session 0A.

---

## Milestone 0 Sessions (Foundation)

### Session M0.1: SBCL Project Skeleton
**Goal**: Create the SBCL project structure — ASDF system, package definitions, entry point.
**Artifacts**: `src/packages.lisp`, `src/main.lisp`, `hngh.asd`, basic `make run`.
**Exit criteria**: `./hngh` starts an SBCL process, logs "Hngh starting...", and exits cleanly.
**Dependencies**: Session 0B.

### Session M0.2: Event Bus
**Goal**: Implement the internal event bus (A2) — pub/sub, topic namespacing, in-process delivery.
**Artifacts**: `src/event-bus.lisp`, unit tests, event journaling to State Store.
**Exit criteria**: Can publish and subscribe to events; events journaled to file; persistent subscriptions work.
**Dependencies**: Session M0.1.

### Session M0.3: State Store
**Goal**: Implement the state store (A3) — file tree read/write, SQLite locks, journal append.
**Artifacts**: `src/state-store.lisp`, unit tests, state tree initialization.
**Exit criteria**: Can read/write files in `~/.hngh/`; SQLite locks acquire/release; journal appends work.
**Dependencies**: Session M0.1.

### Session M0.4: Plugin Host
**Goal**: Implement the plugin host (A1) — CL plugin loading, manifest parsing, package-level isolation.
**Artifacts**: `src/plugin-host.lisp`, unit tests, one test plugin, manifest schema.
**Exit criteria**: Can load a CL plugin from a manifest; plugin runs in its own package; unload works.
**Dependencies**: Sessions M0.2, M0.3.

### Session M0.5: Supervisor
**Goal**: Implement the supervisor (A6) — restart policies, health checks, component registration.
**Artifacts**: `src/supervisor.lisp`, unit tests.
**Exit criteria**: Can register a component with a restart policy; restarts on failure; escalates after N failures.
**Dependencies**: Session M0.2.

### Session M0.6: Scheduler
**Goal**: Implement the scheduler (A5) — timers, basic scheduling.
**Artifacts**: `src/scheduler.lisp`, unit tests.
**Exit criteria**: Can schedule a timer that fires an event at a specified time; cancel works.
**Dependencies**: Session M0.2.

### Session M0.7: dbus Bridge (Minimal)
**Goal**: Implement a minimal dbus bridge (B13) — systemd session bus subscription, basic event translation.
**Artifacts**: `src/plugins/dbus-bridge.lisp`, unit tests, event mapping config.
**Exit criteria**: Can subscribe to systemd session bus signals; events appear on internal bus.
**Dependencies**: Session M0.4 (plugin host).

### Session M0.8: Dashboard TUI (Minimal)
**Goal**: Implement a minimal TUI dashboard (B9) — status display, event feed, basic navigation.
**Artifacts**: `src/plugins/dashboard-tui.lisp`, basic TUI rendering.
**Exit criteria**: TUI starts, shows Hngh status, displays live event feed, responds to quit.
**Dependencies**: Session M0.4 (plugin host).

### Session M0.9: System Daemon Skeleton
**Goal**: Implement the system daemon (C1) skeleton — C skeleton, one dbus method (InstallPackages), systemd units.
**Artifacts**: `systemd/hngh-system.service`, `systemd/hngh-helper@.service`, `src/system-daemon/main.c`, dbus policy file.
**Exit criteria**: System daemon starts as root, exposes InstallPackages on dbus, can run `pacman -S <pkg>`.
**Dependencies**: Session 0B (build system).

### Session M0.10: End-to-End Integration
**Goal**: Wire everything together — start service, load plugin, TUI shows status, install a package.
**Artifacts**: Integration test script, systemd user unit for `hngh.service`.
**Exit criteria**: `systemctl --user start hngh` → TUI shows status → user requests package install → package installs via system daemon.
**Dependencies**: Sessions M0.4–M0.9.

---

## Milestone 1 Sessions (The Harness)

M1 sessions are planned in detail below. Batches are ordered by dependency —
each batch's deliverables are prerequisites for later batches. Within a batch,
sessions are independent and can be parallelized.

### Batch 0: Foundation for M1

- **M1.0a**: Migrate test suite from custom harness to FiveAM (D-013)
  — 78 existing tests rewritten to FiveAM's `def-test`, `def-fixture`,
  `before-each`/`after-each` pattern. Solves state contamination and flaky
  scheduler tests. Design spec sync (SQLite→file-based locks, YAML→plist)
  is included since the docs are already updated.
- **M1.0b**: Design spec sync — already done during M0 critical review.

### Batch 1: Core Security + Resources

- **M1.1**: Procedural threat detection (L1+L3) — static analysis of plugin
  manifests and code, runtime observation of plugin behavior, rules engine.
  Implements `src/core/threat-detection.lisp` (currently a stub).
- **M1.2**: Resource manager (A4) — VRAM/CPU/memory arbitration, preemption,
  hardware audit. Scans system at startup, arbitrates requests from model
  runtime manager and AI tools.

### Batch 2: System Management + Secrets

- **M1.3**: Package manager (B1) — pacman/yay/paru integration, breakage
  detection. Calls system daemon for privileged operations.
- **M1.4**: System config (B2) — /etc management, btrfs snapshots, theming
  files. Calls system daemon for WriteFile and CreateSnapshot.
- **M1.11**: Secrets manager (B8) — 1Password/KeePassXC/vault.age backends,
  policy-checked access, audit log. Moved up from Batch 5 — needed before
  AI tool hub (M1.6) requires API keys.

### Batch 3: AI Infrastructure

- **M1.5**: Model runtime manager (B4) — ollama, llama.cpp, unsloth,
  comfyUI spawn/lifecycle. Depends on M1.2 for VRAM arbitration.
- **M1.6**: AI tool hub (B11) — tool registry, agentic CLI invocation,
  direct API, cost tracking. Depends on M1.11 for API key retrieval.
- **M1.7**: AI orchestrator (B3) — coordinator, context package assembly,
  inter-tool handoffs. Depends on M1.5 and M1.6.

### Batch 4: Security AI + Knowledge

- **M1.8**: LLM threat detector (L2+L4) — on-demand LLM review, periodic
  drift detection. Depends on M1.1 (threat detection) and M1.5 (model
  runtime for local LLM).
- **M1.9**: Hnghbeats (B6) — event condensation, daily beats. Produces
  human-readable summaries from the raw event journal.
- **M1.12**: Knowledge base (B12) — article storage, keyword search,
  learned-pattern recording. Feeds context packages for AI orchestrator.

### Batch 5: Backup + Polish

- **M1.10**: Backup manager (B7) — git versioning of state tree, remote
  sync, restore. Moved down from Batch 5 — not a blocker for other
  components, but needed before M1.14 packaging.
- **M1.13**: KDE integration (B10) — theming, notifications (optional).
- **M1.14**: PKGBUILD + split packages — all five packages (hngh-core,
  hngh-system, hngh-python, hngh-kde, hngh-dev), custom repo.
- **M1.15**: Integration tests — end-to-end tests for all 8 critical flows
  defined in `docs/design/integrations.md`.

---

## Journal Convention

Each work session ends with a journal entry in `docs/journal/YYYY-MM-DD.md`:
- What was done
- What was learned
- What's next
- Decisions made (if any, with mini-ADR)

---

## Session Cadence

Sessions are flexible. The user drives the schedule. The plan is a menu, not a
calendar — pick the next session, do it, mark it done, pick the next.

Dependencies are noted to prevent starting a session before its prerequisites are
complete. Within a batch, sessions are independent and can be parallelized.