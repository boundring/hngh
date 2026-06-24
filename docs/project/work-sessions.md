# Hngh Work Session Plan

**Status**: M1 batches 0–4 complete; Batch 5 next
**Last updated**: 2026-06-24

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

## Pre-Implementation Sessions (done)

### Session 0A: Repo Setup + Project Management
**Status**: Done (2026-06-22)

### Session 0B: Build System + CI Scaffolding
**Status**: Done (2026-06-22)

---

## Milestone 0 Sessions — Foundation (all done, 2026-06-22)

| Session | Title | Status |
|---|---|---|
| M0.1 | SBCL Project Skeleton | Done |
| M0.2 | Event Bus (A2) | Done |
| M0.3 | State Store (A3) | Done |
| M0.4 | Plugin Host (A1) | Done |
| M0.5 | Supervisor (A6) | Done |
| M0.6 | Scheduler (A5) | Done |
| M0.7 | dbus Bridge (Minimal) | Done |
| M0.8 | Dashboard TUI (Minimal) | Done |
| M0.9 | System Daemon Skeleton | Done |
| M0.10 | End-to-End Integration | Done (18 integration tests) |

**Total M0**: 78 unit + 18 integration = 96 tests passing.

---

## Milestone 1 Sessions — The Harness (Batches 0–4 done; Batch 5 next)

M1 sessions are batched by dependency — each batch's deliverables are
prerequisites for later batches. Within a batch, sessions are independent
and can be parallelized.

### Batch 0: Foundation for M1 — done

- **M1.0a**: Migrate test suite from custom harness to FiveAM (D-013)
  — 78 existing tests rewritten to FiveAM's `def-test`, `def-fixture`,
  `before-each`/`after-each` pattern. Solves state contamination and flaky
  scheduler tests. **Done** (commit `8ebcbe4`, 2026-06-23).
- **M1.0b**: Design spec sync — already done during M0 critical review.

### Batch 1: Core Security + Resources — done

- **M1.1**: Procedural threat detection (L1+L3) — static analysis of
  plugin manifests and code, runtime observation of plugin behaviour,
  rules engine. **Done** (commit `f33bbd6`, 2026-06-23). 19 tests.
- **M1.2**: Resource manager (A4) — VRAM/CPU/memory arbitration,
  preemption, hardware audit. **Done** (commit `f33bbd6`, 2026-06-23).
  17 tests.

### Batch 2: System Management + Secrets — done

- **M1.3**: Package manager (B1) — pacman/yay/paru integration,
  breakage detection. **Done** (commit `f45c5c7`, 2026-06-23).
  15 tests.
- **M1.4**: System config (B2) — /etc management, btrfs snapshots,
  theming files. **Done** (commit `f45c5c7`, 2026-06-23). 14 tests.
- **M1.11**: Secrets manager (B8) — local-vault backend (fully
  implemented) plus 1Password/KeePassXC/vault-age stubs. Policy-checked
  access, audit log. **Done** (commit `f45c5c7`, 2026-06-23). 22 tests.

### Batch 3: AI Infrastructure — done

- **M1.5**: Model runtime manager (B4) — ollama, llama.cpp, unsloth,
  comfyUI spawn/lifecycle. **Done** (commit `868de1a`, 2026-06-24).
  13 tests. Then hardened (commit `905ea2f`).
- **M1.6**: AI tool hub (B11) — tool registry, agentic CLI invocation,
  direct API (Anthropic, Google, OpenAI), cost tracking, provider-
  specific auth headers. **Done** (commit `868de1a`, 2026-06-24).
  17 tests. Then hardened (commit `905ea2f`).
- **M1.7**: AI orchestrator (B3) — coordinator, context package
  assembly, inter-tool handoffs, `backend-id` mapping for completion
  events. **Done** (commit `868de1a`, 2026-06-24). 16 tests. Then
  hardened (commit `905ea2f`).

### Batch 4: Security AI + Knowledge — done

- **M1.8**: LLM threat detector (L2+L4) — `review-plugin`,
  `review-behavior`, periodic reviews via scheduler, `threat.flag`
  subscription, persistence under `config/plugins/llm-threat/` and
  `state/plugins/llm-threat/`, KB pattern recording for suspicious
  reviews. **Done** (commit `cc4afa8`, 2026-06-24). 6 tests.
- **M1.9**: Hnghbeats (B6) — daily condensation, deterministic
  summaries, persistence under `journal/hnghbeats/YYYY-MM-DD.lisp`.
  **Done** (commit `cc4afa8`, 2026-06-24). 3 tests.
- **M1.12**: Knowledge base (B12) — article/decision/pattern storage,
  keyword + tag query, lock-aware writes. **Done** (commit `cc4afa8`,
  2026-06-24). 7 tests.

### Batch 5: Backup + Polish — pending

- **M1.10**: Backup manager (B7) — git versioning of state tree,
  remote sync, restore. P1. **Not started.**
- **M1.13**: KDE integration (B10) — theming, notifications (optional,
  P2). **Not started.**
- **M1.14**: PKGBUILD + split packages — five packages
  (`hngh-core`, `hngh-system`, `hngh-python`, `hngh-kde`,
  `hngh-dev`), custom repo. P0. **Not started.**
- **M1.15**: Integration tests — end-to-end shell tests for all 8
  critical flows in `docs/design/integrations.md`. P0.
  **Not started.**

### Cleanup before Batch 5

- Remove orphaned `tests/unit/harness.lisp` and its `:file "harness"`
  entry in `hngh.asd`. Vestigial after FiveAM migration in M1.0a.
- Wire `hngh.asd` `:perform (test-op ...)` body to call
  `(hngh.tests:run-tests)`. Currently a no-op.

**Cumulative test count after M1 batches 0–4**:
227 unit + 18 integration = 245 tests, all passing.

---

## Journal Convention

Each work session ends with a journal entry in `docs/journal/YYYY-MM-DD.md`:
- What was done
- What was learned
- What's next
- Decisions made (if any, with mini-ADR)

Existing journal files:
- `docs/journal/2026-06-22.md` — Design phase + M0 sessions (0A, 0B, M0.1–M0.10)
- `docs/journal/2026-06-23.md` — M1.0a, M1.1+M1.2, M1.3+M1.4+M1.11
- `docs/journal/2026-06-24.md` — M1.5+M1.6+M1.7, hardening, M1.8+M1.9+M1.12

---

## Session Cadence

Sessions are flexible. The user drives the schedule. The plan is a menu, not a
calendar — pick the next session, do it, mark it done, pick the next.

Dependencies are noted to prevent starting a session before its prerequisites are
complete. Within a batch, sessions are independent and can be parallelized.
