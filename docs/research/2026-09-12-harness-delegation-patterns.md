# How do OpenSandbox's contract-first ports, Multica's task-barrier daemon version-follow and worktree GC, and jcode's mode-gated spawn depth and single-writer plan slot compare to hngh's worker/ceremony architecture, and which isolation and supervision patterns transfer to a single-host self-governing kernel?

Status: crystallized 2026-09-12 from research line `harness-delegation-patterns`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-harness-delegation-patterns.md.

# Line Crystallization: Isolation & Supervision Patterns for a Single-Host Self-Governing Kernel

**Line:** How do OpenSandbox's contract-first ports, Multica's task-barrier daemon version-follow and worktree GC, and jcode's mode-gated spawn depth and single-writer plan slot compare to hngh's worker/ceremony architecture, and which isolation and supervision patterns transfer to a single-host self-governing kernel?
**Final state:** contracting → crystallized
**Lifecycle:** expanding (2026-09-12) → contracting (2026-09-12) → crystallized (this transition)

---

## 0. Grounding statement (read first)

This line never obtained verified filesystem reads against `/home/bricker/Projects/etc/hngh` or against the OpenSandbox, Multica, or jcode codebases. The expanding beat ended before any exploration; the contracting beat explicitly declined to invent paths. This crystallization honors that constraint:

- **No file path inside the hngh kernel repository is cited as verified.** The repository location is known only as a pointer from the research program.
- Vault notes under **Prior art** are cited as named; their existence is attested by the line's pointer list, but their contents were not re-read in this transition.
- Claims about OpenSandbox/Multica/jcode internals are **[external]** — pattern-level only, unverified against those codebases.
- Claims about hngh's current implementation are **[verify]** — they are questions to close, not findings.
- Pattern transfers are **[transfer]** — justified by architectural reasoning and vault material, adoptable independent of any specific file.

What follows is the line's lasting record under those epistemic terms.

---

## 1. Findings

### F1. All four external patterns converge on one principle: authority is narrowed at exactly one chokepoint. [transfer]
- OpenSandbox's contract-first ports narrow *what may enter* a worker (only validated contracts).
- jcode's single-writer plan slot narrows *who may mutate* shared state (one process).
- jcode's mode-gated spawn depth narrows *how far* delegation may recurse (a budget).
- Multica's barrier-driven GC narrows *when* per-task state may be destroyed (on verified terminal liveness, not on timers).

On a multi-host system these are four mechanisms. On a **single-host self-governing kernel** they collapse into one: the kernel is small enough that each narrowing can be implemented as a single function, a single field, or a single check — the cheapest possible form of each isolation boundary.

### F2. hngh's worker/ceremony split already has the right shape; the line found no evidence it needs new subsystems. [transfer]
The vault's `sources/SRC-2026-08-24-020` (Hngh Run Contract), `concepts/delegated-contract-verification`, and `entities/bounded-delegation` show hngh already reasons in contracts and delegation. The gap the line identified is not conceptual but *enforcement-shaped*: whether contracts are the **only** spawn path, whether plan writes are **actually serialized**, and whether delegation is **provably bounded**. These are audit questions, not architecture questions.

### F3. Termination and reclamation are the two properties a self-governing kernel most lacks by default. [transfer]
A self-spawning host without a hard depth bound has no proof that delegation trees are finite. A host that accumulates per-task scratch state without a liveness-gated collector has no proof its disk is finite. The external systems independently arrived at both; the line judges these the highest-value transfers.

### F4. Timer-based reclamation is an anti-pattern this line rejects. [transfer]
Multica's barrier approach (collect exactly when the task barrier reports terminal state, version-followed against the daemon) is strictly safer than TTLs for a self-governing kernel, where a slow-but-alive task and a dead task are indistinguishable to a timer.

---

## 2. Recommendations (ranked by cost-to-value)

**R1. Single-chokepoint spawn [transfer; verify before adoption].**
One constructor validates the Run Contract and is the only code path that may fork/exec a worker. No new machinery — only deletion of alternate entry points. *Open:* enumerate spawn sites in the hngh kernel and automation repos; none are currently known by verified path.

**R2. Single-writer plan slot [transfer; verify].**
The ceremony/orchestrator is the sole writer of plan/goal state; workers receive immutable snapshots with their contract. *Open:* determine whether hngh's ceremony already serializes plan writes; if two ceremonies can interleave, that is the first bug to close.

**R3. Spawn depth as a contract budget field [transfer].**
Add `spawn_depth` / `max_spawn_depth` to the Hngh Run Contract schema; decrement at each delegation; reject at validation time, not spawn time. Yields a provable finiteness property (worker trees of depth ≤ N are finite and auditable). Extends `concepts/budget-aware-delegation` from cost budgets to structural budgets.

**R4. Liveness-barrier worktree GC [transfer; external dependency].**
A worktree or per-task scratch state is collectable exactly when its task barrier reports a terminal state, checked against a version-followed daemon view. Never collect on elapsed time. *Open:* the Multica mechanism (task-barrier + daemon version-follow) is unverified against its codebase; adopt the *pattern*, not any assumed implementation detail.

**R5. Do not adopt multi-host mechanisms wholesale [transfer].**
Ports-and-adapters layering, distributed barriers, and daemon fleets are multi-host answers. On one host their value survives only in narrowed-authority form (R1–R4). Adopting the machinery rather than the principle would grow the kernel's trusted surface — the opposite of the goal.

---

## 3. Open threads (for successor lines)

1. **Spawn-site audit [verify].** The concrete deliverable this line could not produce: a verified list of every fork/exec/spawn call site in `/home/bricker/Projects/etc/hngh` and the automation repos. This gates R1.
2. **Ceremony write-serialization check [verify].** Read the ceremony implementation; confirm or refute single-writer plan mutation. Gates R2.
3. **Contract schema versioning.** If R3 adds fields to the Run Contract, how do in-flight workers on older contract versions behave? Interacts with Multica-style version-follow; no vault note yet covers contract versioning.
4. **External verification [external].** All three comparison systems (OpenSandbox, Multica, jcode) were treated as pattern sources only. Any future line claiming their *mechanisms* must read their code; this line's descriptions should not be quoted as fact about those systems.
5. **Composed safety argument.** R1–R4 individually narrow authority; whether their composition yields a stated invariant set (e.g., "every running worker holds a valid contract, a finite remaining depth, and a read-only plan view") is an unproven synthesis worth one focused line.

---

## 4. References

Named and attested by the line's prior-art pointers (existence attested, contents not re-read this transition):

- `concepts/clean-architecture` — Clean Architecture for Agent Systems
- `concepts/clean-architecture-for-machine-intelligences` — Clean Architecture for Machine Intelligences
- `concepts/delegated-contract-verification`
- `concepts/budget-aware-delegation` (created 2026-08-24)
- `entities/bounded-delegation`
- `sources/SRC-2026-08-24-020` — Hngh Run Contract

Named but **not verified** (no file within cited confidently):

- `/home/bricker/Projects/etc/hngh` — hngh kernel repository (path from research program; unread in this line)
- OpenSandbox, Multica, jcode codebases — external; all claims tagged [external]

*Line closed in contracting state. The record's honest summary: four patterns studied, one principle extracted, five recommendations issued, zero files verified — and the verification debt is now the first open thread.*
