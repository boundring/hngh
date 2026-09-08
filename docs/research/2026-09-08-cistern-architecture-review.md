# Review the Cistern emacs game's clean architecture (17K LOC; domain/game/view/input/driver layers, one state object threaded everywhere) against Hngh's own core/edge doctrine — which patterns transfer, which diverge?

Status: crystallized 2026-09-08 from research line `cistern-architecture-review`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-cistern-architecture-review.md.

# Final Structured Summary: Cistern Architecture × Hngh Core/Edge Doctrine

**Line State:** `contracting` (Final Record)
**Date:** 2026-09-08
**Subject:** Review of Cistern Emacs Game Clean Architecture against Hngh Kernel Doctrine

## Executive Conclusion

The Cistern project (17K LOC) validates the **structural viability** of a strict Core/Edge separation in Emacs Lisp, but reveals that **enforcement mechanisms** are the primary divergence risk. While Cistern successfully threads a single state object through `domain/game/view/input/driver` layers, it relies on convention rather than compiler-enforced boundaries. For Hngh, the pattern transfers directly to module layout and data flow, but requires explicit "Port" interfaces and runtime guards to prevent the silent architectural decay inherent in Emacs Lisp's mutable nature.

**Key Finding:** The 5-layer structure is transferable; the *purity* of the core is not guaranteed by the structure alone. Hngh must implement active state validation at the `core/engine` boundary to maintain determinism.

## Findings

### 1. Structural Transferability: High
Cistern’s layering maps cleanly to Hngh’s Core/Edge doctrine:
- **Domain (`core/domain`):** Pure data structures and state definitions. No I/O. This is the "Core" in Hngh terms.
- **Game (`core/engine`):** State transition functions (`State × Event → State`). Pure logic. This is the deterministic heart of Hngh.
- **View/Input/Driver (`edge/*`):** All I/O, rendering, and Emacs integration reside here. This constitutes the "Edge."

The dependency direction (inward) is consistent with Clean Architecture principles and aligns with Hngh’s requirement for a testable core independent of live Emacs frames.

### 2. Critical Divergence: Enforcement vs. Convention
- **Cistern Approach:** Relies on naming conventions, code review, and developer discipline to maintain layer boundaries.
- **Hngh Risk:** Emacs Lisp lacks compile-time dependency checking. `require` statements can easily violate inward-only dependencies if not audited. Mutable state (`setf`, `put`) can silently corrupt the "single state object" pattern if engine functions mutate input state in-place instead of returning new objects.

### 3. The Single State Object Pattern
Cistern’s success hinges on threading **one immutable state object** through all transitions. This is the operational definition of Hngh’s "pure core." However, this pattern is fragile in Lisp without explicit guards. Cistern does not appear to have automated enforcement of state immutability, making it a candidate for silent regression.

## Recommendations

### 1. Adopt 5-Layer Module Layout with Strict Port Interfaces
Implement the following module structure in `/home/bricker/Projects/etc/hngh`:

| Layer | Hngh Path | Responsibility | Dependency Rule |
| :--- | :--- | :--- | :--- |
| Domain | `core/domain` | Pure data, state definitions, validation. | No external deps. |
| Engine | `core/engine` | Pure state transitions. | Depends only on `domain`. |
| View | `edge/view` | Rendering, buffer updates. | Read-only access to `domain`/`engine`. |
| Input | `edge/input` | Keybinding parsing, event normalization. | Depends on `domain` (event types). |
| Driver | `edge/driver` | Emacs integration, redisplay hooks. | Outermost; depends on all inner layers. |

**Action:** Audit existing Hngh code for any `core/*` → `edge/*` dependencies. Refactor to pass data through explicit "Port" interfaces (e.g., `view-render-state`, `input-normalize-event`) rather than direct imports.

### 2. Implement State Guard Mechanism
To enforce the single state object pattern, introduce a runtime guard in `core/engine`:
- **Freeze Input:** Wrap input state before passing to engine functions.
- **Validate Output:** Ensure engine functions return a new state object, not a mutated version of the input.
- **Log Diffs:** Capture state diffs for debugging and repro sandboxing (aligns with prior art `[[sources/debug-repro-sandboxes-only]]`).

This mitigates Emacs Lisp’s mutable nature and ensures core determinism.

### 3. Separate View and Input Ports
Do not fuse `view` and `input` into a single "UI" module. Keep them separate to enable:
- **Replay Testing:** Input events can be replayed against static state without view rendering.
- **Async Rendering:** View updates can be decoupled from event processing.

**Action:** Ensure `edge/input` never directly calls `edge/view` functions. All communication must flow through the core state object.

## Open Threads

1. **Performance Overhead of State Guards:** Will runtime freezing/validation of the single state object introduce measurable latency in Hngh’s hot paths? Needs benchmarking against Cistern’s unguarded approach.
2. **Port Interface Granularity:** How fine-grained should Port interfaces be? Cistern uses direct function calls; Hngh may need formal interface definitions to enforce boundaries. Requires design decision.
3. **Long-Term Maintenance of Convention:** Even with guards, will developers respect layer boundaries over time? Consider adding linting rules or CI checks for dependency direction in Hngh’s build pipeline.

## References

- `/home/bricker/Projects/etc/hngh` (Hngh Kernel Repository)
- `[[cases/cistern-emacs-rewrite]]` (Cistern Emacs Rewrite Case Study)
- `[[sources/cistern-project-findings]]` (Cistern Project Findings)
- `[[concepts/clean-architecture]]` (Clean Architecture for Agent Systems)
- `[[sources/debug-repro-sandboxes-only]]` (Debug Repro Sandboxes)
