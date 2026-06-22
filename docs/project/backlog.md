# Backlog — Future Work Queue

**Last updated**: 2026-06-22

---

## Pre-Implementation

| Session | Title | Status | Priority |
|---|---|---|---|
| 0A | Repo setup + PM scaffolding | Done | P0 |
| 0B | Build system + CI scaffolding | Next | P0 |

## Milestone 0 — Foundation

| ID | Title | Status | Priority | Dependencies |
|---|---|---|---|---|
| M0.1 | SBCL project skeleton | Backlog | P0 | 0B |
| M0.2 | Event bus (A2) | Backlog | P0 | M0.1 |
| M0.3 | State store (A3) | Backlog | P0 | M0.1 |
| M0.4 | Plugin host (A1) | Backlog | P0 | M0.2, M0.3 |
| M0.5 | Supervisor (A6) | Backlog | P1 | M0.2 |
| M0.6 | Scheduler (A5) | Backlog | P1 | M0.2 |
| M0.7 | dbus bridge (B13) | Backlog | P0 | M0.4 |
| M0.8 | Dashboard TUI (B9) | Backlog | P0 | M0.4 |
| M0.9 | System daemon (C1) | Backlog | P0 | 0B |
| M0.10 | End-to-end integration | Backlog | P0 | M0.4–M0.9 |

## Milestone 1 — The Harness (v0.1)

| ID | Title | Status | Priority | Batch |
|---|---|---|---|---|
| M1.1 | Procedural threat detection (L1+L3) | Future | P0 | 1: Security |
| M1.2 | Resource manager (A4) | Future | P0 | 1: Resources |
| M1.3 | Package manager (B1) | Future | P0 | 2: System |
| M1.4 | System config (B2) | Future | P0 | 2: System |
| M1.5 | Model runtime manager (B4) | Future | P0 | 3: AI |
| M1.6 | AI tool hub (B11) | Future | P0 | 3: AI |
| M1.7 | AI orchestrator (B3) | Future | P0 | 3: AI |
| M1.8 | LLM threat detector (L2+L4) | Future | P1 | 4: Security AI |
| M1.9 | Hnghbeats (B6) | Future | P1 | 4: Knowledge |
| M1.10 | Backup manager (B7) | Future | P1 | 5: Backup |
| M1.11 | Secrets manager (B8) | Future | P1 | 5: Backup |
| M1.12 | Knowledge base (B12) | Future | P1 | 4: Knowledge |
| M1.13 | KDE integration (B10) | Future | P2 | 6: Polish |
| M1.14 | PKGBUILD + split packages | Future | P0 | 6: Polish |
| M1.15 | Integration tests | Future | P0 | 6: Polish |

## Milestone 2 — The Companion (v0.2)

Detailed planning deferred until M1 cycle.

## Milestone 3 — The Network (v0.3)

Detailed planning deferred until M2 cycle.

## Open Design Questions (from risk register)

| Question | Target Resolution |
|---|---|
| Plugin manifest schema (YAML vs. Lisp data) | M0.4 (prototype both, pick based on ergonomics) |
| Event bus delivery guarantees (at-least-once confirmed; exactly-once needed?) | M0.2 (test with real workloads) |
| Tool result normalization schema (`ToolResult` struct) | M1.6 (define when first handoff is implemented) |
| KB search: keyword (v0.1) → embeddings (v0.2) transition path | M1.12 (keyword search interface stable) |
| Remote instance protocol (v0.3) | M2 cycle (research during v0.2) |
| Buddy avatar rendering technology | M2 (prototype during v0.2) |
| Cost optimization algorithm (v0.2) | M2 (start rules-based) |