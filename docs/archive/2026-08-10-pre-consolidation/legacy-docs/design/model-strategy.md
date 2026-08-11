# Model Strategy & Quota Management — Self-Expanding Low-Cost Metabolism

**Status**: Draft v0.1 (2026-08-04)
**Author**: PM (z-ai/glm-5.2 via openrouter, Hermes harness)
**Milestone**: M9 Wave 3 (extends model-pareto.md, squad-metabolism.md)

This specification defines our strategies for maintaining squad operations under tight budget constraints ($20/week on OpenRouter, Moonshot Kimi K3 native API depleted until August 8th). It establishes the "Skeleton-Bones-Flesh" development workflow, parallel cheap model fan-out/voting, tight scaffolding for less-intelligent designers, and integration of the **MisakaNet** failure-memory layer to shield our models from repeating known system/environment mistakes.

---

## 1. Budget Restrictions & Model Rotation

The megastructure's growth cannot stall due to depleted premium tokens. We rotate our squad seats down the Pareto frontier to maximize intelligence per millidollar, utilizing local and free models as primary drivers.

### 1.1 PM Rotation Matrix

With `opencode/kimi-k3` native API offline for 4 days, the PM role rotates through lower-cost tiers:

| Tier | Model | Provider | Cost ($/1M in) | Cost ($/1M out) | Note |
|---|---|---|---|---|---|
| Primary | `z-ai/glm-5.2` | openrouter | 0.40 | 0.40 | High reasoning, within the $20/week cap |
| Fallback 1 | `deepseek/deepseek-v4-flash-0731` | openrouter | 0.09* | 0.09* | Cheapest capable; primary for most non-PM roles (2026-08-05 mandate) |
| Fallback 2 | `deepseek/deepseek-v4-flash` | openrouter | 0.09 | 0.14 | Cheap, great for straightforward coordination |
| Fallback 3 | `gpt-5.6-luna` | openai | 0.10 | 0.10 | Low cost, high speed, high syntax-familiarity |
| Quota Floor | `gemma-4-12b` | local (ollama) | 0.00 | 0.00 | Free, unlimited. Use when OR budget exhausted |

### 1.2 Designer Rotation Matrix

The Designer, traditionally a high-reasoning task, is heavily simplified to run on mid-tier or local models by supplying **strict structural templates**:

| Tier | Model | Provider | Strategy |
|---|---|---|---|
| Primary | `z-ai/glm-5.2` | openrouter | Standard design sessions (detailed specs) |
| Fallback | `google/gemini-3.5-flash` | openrouter (free) | High speed, large context, prone to fluff (strip via human filter) |
| Local Floor | `gemma-4-12b` | local (ollama) | Requires structural scaffold (Skeleton templates only) |

---

## 2. Low-Cost Strategy: "Skeleton, Bones, and Flesh"

To keep remote API spend near zero, we divide code implementation into three distinct passes. A task bean is not written in one premium turn. It is grown, reinforced, and then fleshed out.

### 2.1 The Passes

1. **The Skeleton Pass (Cheap — < $0.01)**
   - *Driver*: `deepseek-v4-flash-0731` (primary, cheapest capable) or local
     `gemma-4-12b` as last resort.
   - *Purpose*: Establish interfaces, define package structures, and write RED unit tests.
   - *Deliverable*: `tests/unit/test-*.lisp` and `package.lisp` stubs.
   - *Verification*: Must fail compilation or test run with expected "not implemented" or RED status (`exit-code 2`).

2. **The Bones Pass (Cheap — < $0.01)**
   - *Driver*: `deepseek-v4-flash-0731` or `deepseek-v4-flash`; `luna` next.
   - *Purpose*: Implement the basic structural branches, loop skeletons, and type assertions.
   - *Deliverable*: `src/plugins/*.lisp` logic bones.
   - *Verification*: Compilation succeeds. Tests still fail or return stub/partial results.

3. **The Flesh Pass (Premium / High-Reasoning — Gated)**
   - *Driver*: `z-ai/glm-5.2` or `kimi-k3` (after August 8th).
   - *Purpose*: Implement complex logic branches, recursive depth calculation, and state synchronization.
   - *Trigger*: Gated by the Accountant. Only invoked if the "Bones" compile successfully and the RED test coverage is verified.
   - *Deliverable*: Complete, robust GREEN implementation.

### 2.2 Parallel Fan-Out & Voting (Lisp Synthesis)

When a Bones or Flesh pass fails tests repeatedly (spinning wheels), the PM executes a **Fan-Out** action:
- Dispatch 3 parallel tasks to `deepseek-v4-flash-0731` (cheap) with slightly varied prompt seeds.
- Excrete their outputs to `/tmp/synthesis/`.
- A local script runs `sbcl --load` and `make test` against each candidate's code.
- **The Vote**: The candidate code that passes the most unit tests is selected and merged into `main`. The failed candidates are culled. This leverages cheap parallel search over single-threaded high-cost reasoning.

---

## 3. MisakaNet Integration: The Failure-Memory Shield

Our cheap squads cannot afford to debug the same local environment or platform failures repeatedly (such as SQLite database locks, Telegram cross-thread delivery, or cronjob race conditions). We shield them with `MisakaNet` (github.com/Ikalus1988/MisakaNet), a git-backed micro-lesson failure-memory layer.

### 3.1 The Misaka Guard Architecture

1. **Pre-flight Query**
   - Before a Coder or Worker is dispatched, the PM or Agent CLI automatically checks if there is a known failure-recovery lesson for the task's keywords.
   - Command: `misakanet_search` (misakanet MCP, auto-start in Hermes/OpenCode)
     is queried to match errors; falls back to a local cache of
     `~/.local/share/misakanet` lessons.
   
2. **Post-failure Intake & Healing**
   - When a test run fails with a system error (e.g. `SQLite database is locked`, `UIOP:COMPILE-FILE-ERROR`), the PM intercepts the error log on the event bus (`squad.seat.error`).
   - The PM searches MisakaNet's 249 indexed failure lessons (e.g., `lessons/core/hermes-state-database-lock-issues-cleanup-protocol.md`).
   - If a match is found (relevance > 0.8), the PM injects the exact remedy directly into the active Coder's context and reruns the task:
     > *"MisakaNet Lesson found (hermes-state-database-lock-issues): Your compiler is blocked by an orphaned git process or SQLite lock. Run systemctl restart hermes-gateway.service and checkpoint WAL."*

3. **Contribution**
   - When our squad discovers a unique failure-recovery path (such as the Lisp `allowed-types` let-paren mismatch we just resolved), the Accountant formats a redacted lesson file according to `lessons/TEMPLATE.md` and submits it to MisakaNet's intake via an automated issue or pull request, keeping the global agent network updated.

---

## 4. Tight Scaffolding: Must-Includes & Must-Not-Includes

To allow cheaper models to work as Designers or Coders without veering off-track, their task beans must carry strict, low-entropy structural constraints.

### 4.1 Must-Includes (Constraints)
- **Compiling Verification**: Any Common Lisp plugin code *must* load cleanly via ASDF before a test run is attempted.
- **TDD (Test-First)**: Every implementation task must have an accompanying `test-*.lisp` file that defines at least 3 distinct unit tests.
- **Explicit Functions**: Each task bean must name the exact functions to be defined and their argument signatures.

### 4.2 Must-Not-Includes (Prohibitions)
- **No Concurrent Git-Adds**: Leaf agents must *never* run `git add -A` or `git commit -A` on the parent repository. They must stage only their named, isolated files.
- **No Background Process Leaves**: Agents must never launch background processes that leave orphaned file/git locks after their TUI or session is terminated.
- **No Premium Conversational Loops**: Conversational/Leftover comments must be stripped from source code before verification. Keep code clean, terse, and structural.

---

## 5. Tsutomu Nihei Aesthetic Integration

The megastructure's expansion relies on these tight, mathematical, near-zero cost iterations. 

- **Monospace Structure**: Design documents, status files, and messages are formatted strictly in monospace tables or tree diagrams. No decoration.
- **Light Bean Humor**: A squad that consumes premium tokens without producing green tests is a squad that has "suffered mold." We treat high-cost models as "premium yeast" that must only be added when the dough (skeleton + bones) has been structurally prepared by local wheat (local models).
- **Megastructure Time**: Growth is slow, stratified, and silent. We do not announce milestones; we let the git log speak. A green commit is a stratum laid down. A feral bean is a cancer in the silicon. We prune it immediately.
