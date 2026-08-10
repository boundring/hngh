# Backlog — Future Work Queue

**Last updated**: 2026-07-31 (reconciled with work-sessions.md; M0–M6.2 done,
892 tests green)

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

> **Reality note (2026-07-31)**: M1 closed out informally — the roadmap's
> "batches" gave way to the M2–M6.2 sessions in `work-sessions.md`
> (AI-tool-hub baseURL, event loop, unsloth lifecycle, dogfood loop, mission
> control, agentic loops). M1.13/M1.14/M1.15 remain as leftovers (P2, see
> `next.md`). M2-era items below are still the right sketch for v0.2 but now
> share the horizon with M7 (client-server daemon) and M8 (model management).

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
| **Encoded filename metadata for agent direction** | Design seed — `docs/design/encoded-filename-metadata.md`. Evaluate later: prior art, decode-primitive prototype, token-scope ROI, beans/dispatch-tree interplay. Not on any current build path. |
| **Public vetting — self-optimization / parity / cost accounting** | `docs/design/public-vetting.md` (assessment framing before going public). Researcher: Odysseus & Agent Zero docs-first feature-parity matrix → `docs/research/`; public cost-vs-capability dashboard over the existing ledger; ACP/MCP/A2A multi-tool surface; multi-instance network kept as a design seed (security-first, post-v1). Not scheduled build. |
- **Bounded K3 completion harness** | Design: `docs/design/k3-bounded-completions.md`. Sequence: harden quota truth (128) → planner integration (127, default refuse) → packet schema/fingerprint → manual quota observation gate → no-tools one-turn adapter → Pi feasibility spike → dashboard admission view. No automatic K3 call before observation/config supplies the cap; no unconstrained K3 agentic session. |
| **Model economy + context lifecycle** | Design: `docs/design/model-economy-and-context-lifecycle.md`. Reserve every remote route above $0.20/M input or with UNKNOWN price; 12/18/25% context lifecycle; minimal tool profiles; procedural prompt/component ledger; local/cheap fixture benchmarks only. Cards 128 → 127 → 131 → 132 → 130 → 133 → 134. |
| **Workbench-root consolidation** | **Migration DONE** (`2de5875`, 70 fixture checks; 316+33 file manifests matched; watcher/lane verified). Follow-up: introduce work-root seams, sweep active referencers, and capture the hidden trees in backup-manager without sweeping unrelated dirty runtime state. |

## MisakaNet lesson candidates (submission backlog)

Ideas learned this period worth submitting to MisakaNet as lessons (search is
free; lesson reading paid). Not submitted yet — review + submit when suitable:

| Lesson candidate | Reason it's valuable |
|---|---|
| Paren linter: multi-line docstrings break per-line depth counting | False "unclosed form" on files that compile fine; fix = single full-text pass with cross-line string state (`scripts/lint-parens.py`). |
| Shared test package: duplicate helper names clobber across files | `hngh.tests` is one package; later-loaded test file's `%result` won, causing `UNKNOWN-KEYWORD-ARGUMENT :ARTIFACTS` in an unrelated suite. Namespace per-file helpers. |
| Judge verdicts: (coerce x 'double-float) breaks `=` equality in tests | `0.8d0` ≠ `0.8` under `=`; tests must compare double literals (`0.8d0`) or the code returns single floats. |
| `:none` keyword is truthy in CL | Calibration false-positive counting: `(not (null :none))` is T; check `(eq x :none)` explicitly for sentinel values. |
| Lisp `reserve-judge-call` missing parens → unbound variable | `(when judge-budget-ok-p)` (missing call parens) reads as an unbound variable at runtime; fiveam reports it only when the test invokes the function. |
