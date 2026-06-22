# Hngh Roadmap

**Status**: Planning (pre-implementation)
**Last updated**: 2026-06-22

---

## Overview

Four milestones, dependency-ordered. Each milestone has explicit exit criteria.

| Milestone | Name | Goal | Status |
|---|---|---|---|
| M0 | Foundation | Core image skeleton, end-to-end validation | Not started |
| M1 | The Harness (v0.1) | Full system harness with AI orchestration | Not started |
| M2 | The Companion (v0.2) | Graphical buddies, passive observation, cost optimization | Not started |
| M3 | The Network (v0.3) | Remote instance coordination, knowledge sharing | Not started |

---

## Milestone 0 — Foundation

**Goal**: Get the core image running with minimal plugins for end-to-end validation.

**Exit criteria**: Hngh starts as a systemd user service, loads one first-party CL plugin, displays status in TUI, and can install a package via the System Daemon.

### Deliverables

| ID | Deliverable | Components | Dependencies |
|---|---|---|---|
| M0.1 | SBCL project skeleton + build system | ASDF system definition, project structure, Makefile | — |
| M0.2 | Event bus | A2: internal pub/sub, in-process delivery, event journaling | M0.1 |
| M0.3 | State store | A3: file tree read/write, SQLite locks, journal append | M0.1 |
| M0.4 | Plugin host | A1: CL plugin loading, manifest parsing, package-level isolation | M0.2, M0.3 |
| M0.5 | Supervisor | A6: restart policies, health checks, component registration | M0.2 |
| M0.6 | Scheduler | A5: timers, basic scheduling | M0.2 |
| M0.7 | dbus bridge (minimal) | B13: systemd session bus subscription, basic event translation | M0.2 |
| M0.8 | Dashboard TUI (minimal) | B9: status display, event feed, basic navigation | M0.2 |
| M0.9 | System daemon skeleton | C1: C skeleton, one dbus method (InstallPackages), systemd units | — |
| M0.10 | End-to-end integration test | Full stack: start service → load plugin → TUI shows status → install package | M0.4–M0.9 |

---

## Milestone 1 — The Harness (v0.1)

**Goal**: The full v0.1 scope — a usable system harness with AI orchestration.

**Exit criteria**: A power-user can install Hngh on CachyOS, manage packages, configure their system, run local models, invoke cloud AI, back up their config, and have the threat detection system running — all from the TUI dashboard or programmatically.

### Deliverables

| ID | Deliverable | Components | Dependencies |
|---|---|---|---|
| M1.1 | Procedural threat detection (L1+L3) | A7: static analysis, runtime observation, rules engine | M0.4 |
| M1.2 | Resource manager | A4: VRAM/CPU/memory arbitration, preemption, hardware audit | M0.3 |
| M1.3 | Package manager | B1: pacman/yay/paru integration, breakage detection | M0.7, M0.9 |
| M1.4 | System config | B2: /etc management, btrfs snapshots, theming files | M0.7, M0.9 |
| M1.5 | Model runtime manager | B4: ollama, llama.cpp, unsloth, comfyUI spawn/lifecycle | M1.2 |
| M1.6 | AI tool hub | B11: tool registry, agentic CLI invocation, direct API, cost tracking | M1.2 |
| M1.7 | AI orchestrator | B3: coordinator, context package assembly, inter-tool handoffs | M1.6, M1.5 |
| M1.8 | LLM threat detector (L2+L4) | B5: on-demand LLM review, periodic drift detection | M1.5, M1.1 |
| M1.9 | Hnghbeats | B6: event condensation, daily beats | M0.2 |
| M1.10 | Backup manager | B7: git versioning, remote sync, restore | M0.3 |
| M1.11 | Secrets manager | B8: 1Password/KeePassXC/vault.age backends, policy | M0.3 |
| M1.12 | Knowledge base | B12: article storage, keyword search, learned-pattern recording | M0.3 |
| M1.13 | KDE integration (optional) | B10: theming, notifications | M0.7 |
| M1.14 | PKGBUILD + split packages | All five packages, custom repo | M1.1–M1.13 |
| M1.15 | Integration tests | End-to-end tests for all critical flows | M1.1–M1.13 |

---

## Milestone 2 — The Companion (v0.2)

**Goal**: The system becomes interactive and intelligent.

**Exit criteria**: The system proactively observes user behavior, suggests shortcuts, generates plugins to automate repetitive tasks, and presents a graphical companion that interacts with the user.

### Deliverables (sketch — detailed in v0.1 cycle)

- User Activity Observer — passive observation, periodic questioning, preference model
- Buddy Avatar — graphical animated assistant widget (Wayland/X11), speech bubbles, conversation trees
- Speech Bubble UI — comic-strip-style dialogue renderer
- TTS Voice — local text-to-speech for buddy dialogue
- Cost Optimizer — procedural cost optimization, routes by cost/latency/user-pref
- Subagent Time-Travel — conversation rewinding, inject advice at earlier states
- KB Embeddings — semantic search via local model embeddings
- Advanced Context Management — context compaction, session backtracking, inter-sub-agent monitoring

---

## Milestone 3 — The Network (v0.3)

**Goal**: Hngh instances coordinate across machines.

**Exit criteria**: Users can connect Hngh instances across machines, share knowledge bases, delegate tasks to remote instances, and coordinate backups and configurations across a fleet.

### Deliverables (sketch — detailed in v0.2 cycle)

- Social Network Manager — peer-to-peer coordination, knowledge-base sharing, SSH key coordination
- Remote Instance Coordinator — connection management, event bus bridging to network
- Procedural Portrait Generator — image-gen-powered character portraits (comfyUI)
- Multi-user Support — multiple Hngh instances per machine
- Inbound Network Listener — authenticated inbound for remote coordination

---

## Design Artifacts

The design phase produced four artifacts, version-controlled in `docs/design/`:

| Artifact | Phase | Content |
|---|---|---|
| `architecture-decision-record.md` | 1+2 | 11 locked decisions (D1–D11) |
| `components.md` | 3 | 21 component specifications + architectural principles |
| `integrations.md` | 4 | Integration map, event schema, contracts, 8 sequence diagrams |
| `hngh-design-spec.md` | 5 | Single source of truth (compiles all phases) |