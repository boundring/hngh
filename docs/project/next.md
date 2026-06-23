# Next — Current Work

**Last updated**: 2026-06-22

## Current Status

**Milestone 0 complete** — all 11 sessions done (0A, 0B, M0.1–M0.10)
**Last session**: M0 critical review + fixes (commit e4fd116, 2026-06-23) + Quicklisp setup
**Test count**: 78 unit + 18 integration = 96 total, all passing

## Up Next

**Milestone 1: The Harness (v0.1)** — 15 deliverables across 6 batches.

### Batch 1: Core Security + Resources
- **M1.1**: Procedural threat detection (L1+L3) — static analysis, runtime observation
- **M1.2**: Resource manager (A4) — VRAM/CPU arbitration, preemption, hardware audit

### Batch 2: System Management
- **M1.3**: Package manager (B1) — pacman/yay/paru, breakage detection
- **M1.4**: System config (B2) — /etc management, btrfs snapshots, theming

### Batch 3: AI Infrastructure
- **M1.5**: Model runtime manager (B4) — ollama, llama.cpp, unsloth, comfyUI
- **M1.6**: AI tool hub (B11) — tool registry, agentic CLI invocation, direct API
- **M1.7**: AI orchestrator (B3) — coordinator, context packages, inter-tool handoffs

### Batch 4: Security AI + Knowledge
- **M1.8**: LLM threat detector (L2+L4) — on-demand review, drift detection
- **M1.9**: Hnghbeats (B6) — event condensation, daily beats
- **M1.12**: Knowledge base (B12) — article storage, keyword search, learned patterns

### Batch 5: Backup + Secrets
- **M1.10**: Backup manager (B7) — git versioning, remote sync, restore
- **M1.11**: Secrets manager (B8) — 1Password/KeePassXC/vault.age, policy

### Batch 6: Polish + Packaging
- **M1.13**: KDE integration (B10) — theming, notifications (optional)
- **M1.14**: PKGBUILD + split packages — all five packages, custom repo
- **M1.15**: Integration tests — all 8 critical flows

See `docs/project/roadmap.md` for full M1 deliverable list.
See `docs/project/work-sessions.md` for detailed session plans.

M1 sessions will be planned in detail when we start M1 work.

## Key Architecture Decisions (for context carry-forward)

- **Language**: SBCL Common Lisp (core) + C (system daemon) + Python (AI, future) + C/C++ (GPU)
- **Architecture**: Image + Bus + Supervisor (microkernel-style)
- **State**: File tree (git-versioned) + file-based locks (SQLite deferred, D-007)
- **Event bus**: Custom internal pub/sub + dbus bridge plugin
- **Plugin isolation**: Package-level (D11)
- **Manifest format**: Lisp plist (D-008, not YAML)
- **Scheduler actions**: Function objects, not quoted forms (D-009)
- **Threat detection**: Procedural-first (L1/L3 in-image), LLM-strategic (L2/L4 plugin)
- **Privilege**: Split daemon — user daemon (CL) + system daemon (C, root, stateless)
- **TUI**: Raw ANSI escape codes (defparameter, not defconstant — SBCL EQL issue)
- **dbus**: cl-ppcre parsing implemented; cl-dbus can replace gdbus subprocess when available
- **Test harness**: Custom (D-005, FiveAM migration now possible — FiveAM installed)
- **Thread safety**: bordeaux-threads mutexes on all shared state (event-bus, scheduler, supervisor, TUI)
- **READ safety**: *read-eval* bound to nil for all untrusted file reads
- **Startup**: *running* set after all components initialized; unwind-protect rolls back on failure
- **License**: AGPL-3.0-or-later

## Environment (ready for M1)

- **SBCL**: 2.6.5 (via pacman, CachyOS)
- **Quicklisp**: installed at `~/quicklisp/`, dist 2026-01-01, auto-loaded via `~/.sbclrc`
- **CL packages installed** (via pacman + Quicklisp):
  - `bordeaux-threads` — mutexes (now used for all shared state)
  - `cffi` — foreign function interface (for C interop, GPU libs)
  - `cl-json` — JSON parsing (for AI tool hub, config)
  - `cl-ppcre` — regex (now used for dbus signal parsing)
  - `alexandria` — utilities (general purpose)
  - `fiveam` — test framework (migration from custom harness now possible)
- **ASDF dependencies**: :bordeaux-threads, :cl-ppcre
- **Available via Quicklisp when needed**: cl-dbus, cl-charms, cl-sqlite, cl-yaml

## Repository

- GitHub: https://github.com/boundring/hngh (primary, issues, milestones)
- Codeberg: https://codeberg.org/hngh/hngh (mirror)
- Local: ~/Projects/etc/hngh/
- Design artifacts: docs/design/ (ADR, components, integrations, design spec)
- Project management: docs/project/ (roadmap, work-sessions, next, done, backlog, decisions)

## Blocked

Nothing blocked. Quicklisp set up, CL packages installed. Codeberg mirror pushed. GitHub project board configured (views need manual creation via web UI).

## Notes

- Codeberg SSH key unlocked and working
- GitHub Projects API auth refreshed (`project` scope)
- All 11 M0 issues linked to project board
- Custom fields: Status, Priority, Phase, Size
- Project board URL: https://github.com/users/boundring/projects/1
- Views (Kanban, Roadmap) need manual creation via web UI — no API support