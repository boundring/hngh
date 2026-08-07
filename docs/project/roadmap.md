# Hngh Roadmap

**Status**: M1 Batches 0–5 complete. M7 daemon committed. Phase 2 protocol handlers merged. M2 session lifecycle & window management complete. M9 squad autonomy W1-3 done (C1, C2, C3, C5, C7), wave 2-4 plugins wired, W5 prompt matrix + free-tier refresh committed (494/494 fast green @ 78cfde9, full suite green; C4 + C10 design-only). hngh-up plugin + design doc added (M1.15 integration / M2 boundary).
**Last updated**: 2026-08-06

---

## Overview

Four milestones, dependency-ordered. Each milestone has explicit exit criteria.

| Milestone | Name | Goal | Status |
|---|---|---|---|
| M0 | Foundation | Core image skeleton, end-to-end validation | **Complete** (96 tests passing) |
| M1 | The Harness (v0.1) | Full system harness with AI orchestration | **In progress** (Batches 0–4 done + M1.10; 12/15 deliverables) |
| M2 | The Companion (v0.2) | Session lifecycle, window management, config watcher, cascading restart, TUI QoL | **Complete** (494/494 fast tests passing @ 78cfde9) |
| M3 | The Network (v0.3) | Remote instance coordination, knowledge sharing | Not started |

---

## Milestone 0 — Foundation (complete)

**Goal**: Get the core image running with minimal plugins for end-to-end validation.
**Exit criteria** (achieved): Hngh starts as a systemd user service, loads one first-party CL plugin, displays status in TUI, and can install a package via the System Daemon.

### Deliverables (all done)

| ID | Deliverable | Components | Status |
|---|---|---|---|
| M0.1 | SBCL project skeleton + build system | ASDF system definition, project structure, Makefile | Done |
| M0.2 | Event bus | A2: internal pub/sub, in-process delivery, event journaling | Done |
| M0.3 | State store | A3: file tree read/write, SQLite locks, journal append | Done |
| M0.4 | Plugin host | A1: CL plugin loading, manifest parsing, package-level isolation | Done |
| M0.5 | Supervisor | A6: restart policies, health checks, component registration | Done |
| M0.6 | Scheduler | A5: timers, basic scheduling | Done |
| M0.7 | dbus bridge (minimal) | B13: systemd session bus subscription, basic event translation | Done |
| M0.8 | Dashboard TUI (minimal) | B9: status display, event feed, basic navigation | Done |
| M0.9 | System daemon skeleton | C1: C skeleton, one dbus method (InstallPackages), systemd units | Done |
| M0.10 | End-to-end integration test | Full stack: start service → load plugin → TUI shows status → install package | Done (18 integration tests) |

---

## Milestone 1 — The Harness (v0.1) — **in progress**

**Goal**: The full v0.1 scope — a usable system harness with AI orchestration.
**Exit criteria**: A power-user can install Hngh on CachyOS, manage packages, configure their system, run local models, invoke cloud AI, back up their config, and have the threat detection system running — all from the TUI dashboard or programmatically.

**Status**: 11 of 12 deliverables implemented (commits 8ebcbe4, f33bbd6, f45c5c7, 868de1a, 905ea2f, cc4afa8). M1-era split: 227 unit + 18 integration tests (historical; current: 494/494 fast green, full suite green).

### Deliverables

| ID | Deliverable | Components | Status | Tests |
|---|---|---|---|---|
| M1.0a | Migrate test suite to FiveAM (D-013) | Test framework | Done | (infra) |
| M1.1 | Procedural threat detection (L1+L3) | A7: static analysis, runtime observation, rules engine | Done | 19 |
| M1.2 | Resource manager | A4: VRAM/CPU/memory arbitration, preemption, hardware audit | Done | 17 |
| M1.3 | Package manager | B1: pacman/yay/paru integration, breakage detection | Done | 15 |
| M1.4 | System config | B2: /etc management, btrfs snapshots, theming files | Done | 14 |
| M1.5 | Model runtime manager | B4: ollama, llama.cpp, unsloth, comfyUI spawn/lifecycle | Done | 13 |
| M1.6 | AI tool hub | B11: tool registry, agentic CLI invocation, direct API, cost tracking | Done | 17 |
| M1.7 | AI orchestrator | B3: coordinator, context package assembly, inter-tool handoffs | Done | 16 |
| M1.8 | LLM threat detector (L2+L4) | B5: on-demand LLM review, periodic drift detection | Done | 6 |
| M1.9 | Hnghbeats | B6: event condensation, daily beats | Done | 3 |
| M1.10 | Backup manager | B7: git versioning, remote sync, restore | Done | 16 |
| M1.11 | Secrets manager | B8: 1Password/KeePassXC/vault.age backends, policy | Done | 22 |
| M1.12 | Knowledge base | B12: article storage, keyword search, learned-pattern recording | Done | 7 |
| M1.13 | KDE integration (optional) | B10: theming, notifications | Future (P2) | — |
| M1.14 | PKGBUILD + split packages | All five packages, custom repo | Future | — |
| M1.15 | Integration tests | End-to-end tests for all 8 critical flows | Future | — |

### Batch progress

| Batch | Deliverables | Status |
|---|---|---|
| 0: Foundation | M1.0a | **Done** |
| 1: Security + Resources | M1.1, M1.2 | **Done** |
| 2: System + Secrets | M1.3, M1.4, M1.11 | **Done** |
| 3: AI Infrastructure | M1.5, M1.6, M1.7 | **Done** |
| 4: Security AI + Knowledge | M1.8, M1.9, M1.12 | **Done** |
| 5: Backup + Polish | M1.10 ✓, M1.13, M1.14, M1.15 | In progress (M1.10 done) |

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

### NET-1 prep notes (2026-07-31 — text only, no code)

- **M7 as groundwork**: the client-server daemon mode (Emacs-style headless +
  extensible clients) is the on-ramp — a daemon that already serves local
  clients over a socket is most of an Inbound Network Listener. Design M7's
  wire protocol so it can later carry auth + remote peers without a rewrite.
- **Steam Deck as first LAN node**: Deck on the LAN already; it runs Arch
  (SteamOS). Candidate first remote instance: low-power, always on the couch.
  Needs: hngh-core package (M1.14 PKGBUILD) or a manual sbcl core deploy.
- **Steam as distribution route**: package hngh as a Steam "tool"/non-game app
  — `systemd --user` service for the daemon (no game-slot occupancy, starts
  with the session). Roadmap note only; depends on M1.14 packaging discipline.
- **Arbitrary device pooling + social aspect**: the M3 lineage — any machine a
  user trusts joins the fleet (desktop, Deck, laptop, VPS); instances share
  KB, delegate tasks by cost/capability, coordinate backups. Social: multiple
  users' instances can peer (multi-user support + authenticated listener).
  Design questions to resolve in the v0.2 cycle: peer identity (SSH keys vs
  age), event-bus bridging semantics across WAN jitter, and whether the cost
  ledger (llm-budget pattern) becomes fleet-wide.

---

## Milestone 9 — Squad Autonomy (not started)

**Goal**: squads self-orient off per-directory AGENTS.md, respect resource/
budget limits at creation, launch immediately by default, extend work into
reviewable fragments instead of stopping cold, and feed a recursive
plan→task→squad cycle that hngh runs against its own roadmap. Squads test
and benchmark squads; nightly cron turns that into a real dataset.

**Design**: `docs/design/squad-autonomy.md` — 9 capabilities (C1–C9), waved
1–5, each wave has zero-further-interview acceptance criteria.
**Depends on**: agent-platoons.md (squad specs, exists), hngh-up.md
(questionnaire, exists — M1.15 boundary), `core/resource-manager.lisp`
(grants/preemption, exists, currently unused by squads).

| Wave | Capabilities | Status |
|---|---|---|
| 1 | C1 AGENTS.md discovery/merge, C5 fragment journal | **Done** (494/494 tests @ 78cfde9) |
| 2 | C3 questionnaire-from-AGENTS.md, C2 resource-gate preflight | **Done** (C2 + C3, 494/494 tests @ 78cfde9; wired main.lisp) |
| 3 | C4 start-now/pause-on-cause, C7 self-written prompts, C10 MisakaNet Failure Shield | **In progress** (C7 done: generate-pm-prompt exported, tested, squad-up wired, now delegates to W5 generate-prompt; C4 + C10 design-only) |
| 4 | C6 planner cycle (roadmap → task queue → squad dispatch) | Not started |
| 5 | C8 benchmark-runner strategy, C9 nightly benchmark cron | Not started |

---

## Design Artifacts

The design phase produced four artifacts, version-controlled in `docs/design/`:

| Artifact | Phase | Content |
|---|---|---|
| `architecture-decision-record.md` | 1+2 | 11 locked decisions (D1–D11) |
| `components.md` | 3 | 21 component specifications + architectural principles |
| `integrations.md` | 4 | Integration map, event schema, contracts, 8 sequence diagrams |
| `hngh-design-spec.md` | 5 | Single source of truth (compiles all phases) |
| `squad-autonomy.md` | M9 | AGENTS.md-oriented, resource-aware, self-continuing squads; recursive planner cycle |
| `autonomy-strategy.md` | M9+ | Research synthesis: self-developing/self-healing engine, clean-arch self-modification guardrails, security hardening (OWASP agentic), cheap-inference + cost control, MCP/A2A/fleet interop — wave-ordered plan + open questions |
| `swe-selfdev-research.md` | M9+ | Cited deep-dive on autonomous SWE agents (SWE-agent, Codex, OpenHands, Agentless, Reflexion), self-healing systems, and pitfalls |
| `security-agentic-research.md` | M9+ | Cited deep-dive on prompt injection, CIA-Triple-A, supply chain, self-modifying-code and multi-instance risks |
| `coordination-patterns-research.md` | M9+ | Cited multi-agent coordination/memory/perception/review patterns mapped to Hngh mechanics |

Light-weight day-to-day decisions are in `docs/project/decisions.md` (D-001 through D-020).
