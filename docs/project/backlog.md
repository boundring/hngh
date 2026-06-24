# Backlog — Future Work Queue

**Last updated**: 2026-06-24

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

| ID | Title | Status | Tests | Batch |
|---|---|---|---|---|
| M1.0a | Migrate test suite to FiveAM | Done | (infra) | 0: Foundation |
| M1.1 | Procedural threat detection (L1+L3) | Done | 19 | 1: Security + Resources |
| M1.2 | Resource manager (A4) | Done | 17 | 1: Security + Resources |
| M1.3 | Package manager (B1) | Done | 15 | 2: System + Secrets |
| M1.4 | System config (B2) | Done | 14 | 2: System + Secrets |
| M1.11 | Secrets manager (B8) | Done | 22 | 2: System + Secrets |
| M1.5 | Model runtime manager (B4) | Done | 13 | 3: AI Infrastructure |
| M1.6 | AI tool hub (B11) | Done | 17 | 3: AI Infrastructure |
| M1.7 | AI orchestrator (B3) | Done | 16 | 3: AI Infrastructure |
| M1.8 | LLM threat detector (L2+L4) | Done | 6 | 4: Security AI + Knowledge |
| M1.9 | Hnghbeats (B6) | Done | 3 | 4: Security AI + Knowledge |
| M1.12 | Knowledge base (B12) | Done | 7 | 4: Security AI + Knowledge |
| M1.10 | Backup manager (B7) | Done | 16 | 5: Backup + Polish |
| M1.13 | KDE integration (B10) | Future | — | 5: Backup + Polish (P2, included in v0.1 per user) |
| M1.14 | PKGBUILD + split packages | Future | — | 5: Backup + Polish |
| M1.15 | Integration tests (M1) | Future | — | 5: Backup + Polish |
| **M1 total** | | **12/15 done** | **165 M1 unit tests** | Batches 0–4 + M1.10 done |

**Cumulative totals (M0 + M1 through M1.10)**:
- Unit tests: 78 (M0) + 165 (M1) = **243** (1090 FiveAM checks)
- Integration tests: 18 (M0 only; M1 integration tests = M1.15, pending)
- All passing.

## Milestone 2 — The Companion (v0.2)

Detailed planning deferred until M1 cycle completes.

Sketch deliverables: User Activity Observer, Buddy Avatar, Speech Bubble
UI, TTS Voice, Cost Optimizer, Subagent Time-Travel, KB Embeddings,
Advanced Context Management.

## Milestone 3 — The Network (v0.3)

Detailed planning deferred until M2 cycle.

Sketch deliverables: Social Network Manager, Remote Instance Coordinator,
Procedural Portrait Generator, Multi-user Support, Inbound Network Listener.

---

## Backlog Notes

### Carryover from M1
- ~~**M1.10 (Backup Manager, B7)**~~ — **Done 2026-06-24** (Oracle-reviewed,
  hardened H1–H5). Follow-up: a `verify-history` command to audit git history
  for forbidden paths before first push to a public remote (D-028/M1 limitation).
- **M1.13 (KDE integration, B10)**: optional, P2. Theming and DBus
  notifications through `org.hngh.*`. Skip if scope exceeds v0.1 budget.
- **M1.14 (PKGBUILD + split packages)**: needed before any Arch package
  release. Five packages (hngh-core, hngh-system, hngh-python, hngh-kde,
  hngh-dev) per design spec.
- **M1.15 (M1 integration tests)**: shell scripts for all 8 critical
  flows in `docs/design/integrations.md`. Currently only M0 has
  integration tests (`m0-full-stack.sh`).

### Cleanup items identified during M1
- Remove orphaned `tests/unit/harness.lisp` (vestigial after FiveAM
  migration). Also remove its `:file "harness"` entry from `hngh.asd`.
- Wire `hngh.asd` `:perform (test-op ...)` body to call
  `(hngh.tests:run-tests)`. Currently `asdf:test-system` does nothing;
  `make test` bypasses via direct SBCL invocation.

### Open Design Questions (from risk register)

| Question | Target Resolution |
|---|---|
| ~~Plugin manifest schema (YAML vs. Lisp data)~~ | **Resolved (D-008)**: Lisp plist |
| Event bus delivery guarantees (at-least-once confirmed; exactly-once needed?) | **Mostly resolved** — at-least-once + journal replay covers current scope. Revisit if M2 needs exactly-once |
| Tool result normalization schema (`ToolResult` struct) | **Resolved (M1.6/M1.7)** — `invocation-info-result` / `invocation-info-error` fields plus `agent-info-result` |
| KB search: keyword (v0.1) → embeddings (v0.2) transition path | M2 cycle (semantic search via local model embeddings) |
| Remote instance protocol (v0.3) | M3 cycle (research during v0.2) |
| Buddy avatar rendering technology | M2 (prototype during v0.2) |
| Cost optimization algorithm (v0.2) | M2 (start rules-based) |
| Backup strategy for `state/plugins/` | M1.10 (backup manager, B7) |
| KDE notification protocol | M1.13 (B10, optional) |
