# Backlog — Future Work Queue

**Last updated**: 2026-06-22

---

## Pre-Implementation

| Session | Title | Status | Priority |
|---|---|---|---|
| 0A | Repo setup + PM scaffolding | Done | P0 |
| 0B | Build system + CI scaffolding | Done | P0 |

## Milestone 0 — Foundation (complete)

| ID | Title | Status | Tests |
|---|---|---|---|
| M0.1 | SBCL project skeleton | Done | 12 |
| M0.2 | Event bus (A2) | Done | 11 |
| M0.3 | State store (A3) | Done | 17 |
| M0.4 | Plugin host (A1) | Done | 11 |
| M0.5 | Supervisor (A6) | Done | 11 |
| M0.6 | Scheduler (A5) | Done | 6 |
| M0.7 | dbus bridge (B13) | Done | 3 |
| M0.8 | Dashboard TUI (B9) | Done | 6 |
| M0.9 | System daemon (C1) | Done | (integration) |
| M0.10 | End-to-end integration | Done | 18 integration |
| **Total** | | | **78 unit + 18 integration** |
## Milestone 1 — The Harness (v0.1)

| ID | Title | Status | Priority | Batch |
|---|---|---|---|---|
| M1.0a | Migrate test suite to FiveAM | Next | P0 | 0: Foundation |
| M1.1 | Procedural threat detection (L1+L3) | Future | P0 | 1: Security + Resources |
| M1.2 | Resource manager (A4) | Future | P0 | 1: Security + Resources |
| M1.3 | Package manager (B1) | Future | P0 | 2: System + Secrets |
| M1.4 | System config (B2) | Future | P0 | 2: System + Secrets |
| M1.11 | Secrets manager (B8) | Future | P0 | 2: System + Secrets |
| M1.5 | Model runtime manager (B4) | Future | P0 | 3: AI Infrastructure |
| M1.6 | AI tool hub (B11) | Future | P0 | 3: AI Infrastructure |
| M1.7 | AI orchestrator (B3) | Future | P0 | 3: AI Infrastructure |
| M1.8 | LLM threat detector (L2+L4) | Future | P1 | 4: Security AI + Knowledge |
| M1.9 | Hnghbeats (B6) | Future | P1 | 4: Security AI + Knowledge |
| M1.12 | Knowledge base (B12) | Future | P1 | 4: Security AI + Knowledge |
| M1.10 | Backup manager (B7) | Future | P1 | 5: Backup + Polish |
| M1.13 | KDE integration (B10) | Future | P2 | 5: Backup + Polish |
| M1.14 | PKGBUILD + split packages | Future | P0 | 5: Backup + Polish |
| M1.15 | Integration tests | Future | P0 | 5: Backup + Polish |

## Milestone 2 — The Companion (v0.2)

Detailed planning deferred until M1 cycle.

## Milestone 3 — The Network (v0.3)

Detailed planning deferred until M2 cycle.

## Open Design Questions (from risk register)

| Question | Target Resolution |
|---|---|
| ~~Plugin manifest schema (YAML vs. Lisp data)~~ | **Resolved (D-008)**: Lisp plist |
| Event bus delivery guarantees (at-least-once confirmed; exactly-once needed?) | M1.0a (revisit during FiveAM migration) |
| Tool result normalization schema (`ToolResult` struct) | M1.6 (define when first handoff is implemented) |
| KB search: keyword (v0.1) → embeddings (v0.2) transition path | M1.12 (keyword search interface stable) |
| Remote instance protocol (v0.3) | M2 cycle (research during v0.2) |
| Buddy avatar rendering technology | M2 (prototype during v0.2) |
| Cost optimization algorithm (v0.2) | M2 (start rules-based) |