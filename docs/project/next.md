# Next — Current Work

**Last updated**: 2026-06-24

## Current Status

**Milestone 0 complete** (commit b89abc7) — 78 unit + 18 integration = 96 tests, all passing.
**Milestone 1 batches 0–4 complete** (commits 8ebcbe4, f33bbd6, f45c5c7, 868de1a, 905ea2f, cc4afa8) — 11 feature deliverables.
**Batch 5 in progress**: M1.10 Backup Manager done (Oracle-reviewed + hardened); M1 integration hardening done (D-030).
**Cumulative after integration hardening**: 248 unit + 18 integration = 266 tests, all passing (1103 FiveAM checks).
**Last session**: M1 alignment review + integration hardening — closed 4 verified event-wiring gaps (plugin.* events, hnghbeats wildcard, agent.completed self-loop, dbus system.* normalization).

## Up Next

**Milestone 1: The Harness (v0.1)** — Batches 0–4 done; **Batch 5 in progress**.

### Alignment status (from the 2026-06-24 review)
Feature plumbing is strongly aligned (12/15 deliverables). The remaining gap to the v0.1 exit criteria ("install on CachyOS … all from the TUI dashboard") is the **end-to-end experience**: packaging, dashboard depth, and validated integration flows.

### Batch 5: remaining
- **Dashboard depth (NEW — unplanned gap)**: the TUI is still the M0 stub (3/9 views, no M1 plugin integration). Needed for the "all from the TUI dashboard" exit criterion. Implement 6 missing views (Packages, Agents, Resources, Threats, Config, Secrets) + topic-filtered subscriptions + calls into the M1 plugins.
- **M1.13**: KDE integration (B10) — theming, notifications. P2 (included in v0.1 per user).
- **M1.14**: PKGBUILD + split packages — five packages (hngh-core, hngh-system, hngh-python, hngh-kde, hngh-dev), custom repo. P0. (Needed for "install on CachyOS".)
- **M1.15**: Integration tests — end-to-end tests for the 8 flows in `docs/design/integrations.md`. P0. (Wiring now hardened, so these validate a correct system; backup flow 4.7 unblocked by M1.10.)

### Deferred follow-ups (non-blocking)
- Plugin *behavioral* observation events (`plugin.subprocess-started`, `plugin.file-accessed`, …) — L3 handles these topics but nothing emits them; needs runtime instrumentation (likely M2).
- `verify-history` command for the Backup Manager (D-028/M1); optional `harness.lisp` rename (D-026); history ring-buffer cap (Oracle L2).

### M1.10 follow-ups (deferred, non-blocking)
- `verify-history` command to audit git history for forbidden paths before first push to a public remote (mitigates the prior-committed-secrets limitation, D-028/M1).
- Optional rename `tests/unit/harness.lisp` → `fiveam-harness.lisp` (D-026); history ring-buffer cap (Oracle L2).

See `docs/project/roadmap.md` for full M1 deliverable list.
See `docs/project/work-sessions.md` for detailed session plans.
M1 sessions completed are journaled in `docs/journal/2026-06-23.md` and `docs/journal/2026-06-24.md`.

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
- **Test harness**: FiveAM (D-013, migrated from custom in M1.0a)
- **Thread safety**: bordeaux-threads mutexes on all shared state (event-bus, scheduler, supervisor, TUI, threat-detection flags, secrets access log, KB write lock, llm-threat history append, resource manager grants)
- **READ safety**: *read-eval* bound to nil for all untrusted file reads (threat-detection code analysis, llm-threat safe-read-state)
- **Startup**: *running* set after all components initialized; unwind-protect rolls back on failure
- **License**: AGPL-3.0-or-later (D-003)

### M1-era additions
- **AI tool keys**: API keys retrieved from Secrets Manager and passed to
  subprocess via environment variables (never command line). Direct API
  uses temp files for headers + payload to avoid process-arg leakage.
- **Grant lifecycle**: Resource grants are scoped per request and released
  via `hngh.core.resource-manager:release` after use. Preemption path
  releases grants before stopping runtimes (M1.5 hardening).
- **Agent handoff**: Orchestrator tracks `backend-id` separately from
  agent ID to map completion events from either naming scheme (M1.7
  hardening).
- **Trust tier**: AI-generated plugins must include `:review` section in
  manifest and trigger mandatory L2 review (threat-detection rule).
- **AI-generated confidence**: LLM threat detector downshifts confidence
  by one notch for `:trust-tier :ai-generated` plugins (D-018).

## Environment (ready for M1)

- **SBCL**: 2.6.5 (via pacman, CachyOS)
- **Quicklisp**: installed at `~/quicklisp/`, dist 2026-01-01, auto-loaded via `~/.sbclrc`
- **CL packages installed** (via pacman + Quicklisp):
  - `bordeaux-threads` — mutexes (now used for all shared state)
  - `cffi` — foreign function interface (for C interop, GPU libs)
  - `cl-json` — JSON parsing (for AI tool hub, config)
  - `cl-ppcre` — regex (now used for dbus signal parsing)
  - `alexandria` — utilities (general purpose)
  - `fiveam` — test framework (migrated from custom harness in M1.0a)
- **ASDF dependencies**: :bordeaux-threads, :cl-ppcre
- **Available via Quicklisp when needed**: cl-dbus, cl-charms, cl-sqlite, cl-yaml

## Repository

- GitHub: https://github.com/boundring/hngh (primary, issues, milestones)
- Codeberg: https://codeberg.org/hngh/hngh (mirror)
- Local: ~/Projects/etc/hngh/
- Design artifacts: docs/design/ (ADR, components, integrations, design spec)
- Project management: docs/project/ (roadmap, work-sessions, next, done, backlog, decisions)
- Journal: docs/journal/YYYY-MM-DD.md (one file per work day)

## Blocked

Nothing blocked. M1 Batch 5 unblocked and ready to start.

## Notes

- Codeberg SSH key unlocked and working
- GitHub Projects API auth refreshed (`project` scope)
- All 11 M0 issues + 12 M1 issues linked to project board
- Custom fields: Status, Priority, Phase, Size
- Project board URL: https://github.com/users/boundring/projects/1
- Views (Kanban, Roadmap) need manual creation via web UI — no API support
- Local ollama server is running on `:11434` — used by M1.5 tests for real health checks and spawn
