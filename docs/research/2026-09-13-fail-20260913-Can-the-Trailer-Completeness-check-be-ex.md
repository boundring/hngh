# Can the "Trailer Completeness" check be extended to handle helper-delegated terminal emissions by analyzing call graphs within `hngh-automation`, or is interprocedural analysis required for accurate false-positive suppression?

Status: crystallized 2026-09-13 from research line `fail-20260913-Can-the-Trailer-Completeness-check-be-ex`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260913-Can-the-Trailer-Completeness-check-be-ex.md.

# Research Line Contraction: Trailer Completeness & Call-Graph Analysis

**Line:** Can the "Trailer Completeness" check be extended to handle helper-delegated terminal emissions by analyzing call graphs within `hngh-automation`, or is interprocedural analysis required for accurate false-positive suppression?
**State:** contracting → **closed (final record)**
**Model:** unsloth:unsloth/Qwen3.8-27B-GGUF

---

## Findings

### F1 — Direct same-package delegation is the dominant false-positive source

The "Trailer Completeness" check in `hngh-automation` flags a unit as incomplete when it does not lexically contain a terminal emission (e.g., a call to `hngh.EmitTrailer(ctx, record)` or an equivalent kernel-side emission). In practice, many units delegate the emission to a same-package helper function. The prior beats established that this delegation pattern accounts for the large majority of observed false positives in CI/rung history. Because Go's package model makes same-package symbols lexically visible without import indirection, a local AST walk over `go/ast` nodes within a single compilation unit can resolve these calls deterministically. No cross-package symbol resolution is needed for this class.

### F2 — Dynamic dispatch defeats purely intraprocedural suppression

Go permits terminal emissions to be reached through interface method calls (`emitter.Emit(ctx, rec)`) and function-value invocation (`emitFn(ctx, rec)`). A checker that only inspects the lexical body of the checked unit cannot determine whether an interface-typed receiver or a `func`-typed variable ultimately dispatches to a concrete emitter. Resolving this requires at minimum a conservative points-to analysis (CHA-style) across package boundaries, or runtime-type-analysis (RTA) if precision is demanded. The line found that building such an analyzer inside `hngh-automation` would introduce a dependency on the full type graph of every transitively imported package, including the hngh kernel repository at `/home/bricker/Projects/etc/hngh`, which is outside the automation repo's own compilation scope. This coupling is disproportionate to the check's purpose.

### F3 — The check is path-sensitive reachability, not mere presence

A terminal emission that sits inside a conditional branch (`if err != nil { return }` before the emit) does not guarantee the trailer is written on all exit paths. The prior beats reframed the invariant: for every reachable exit point of the checked unit (explicit `return`, implicit fall-through at end-of-function, `panic`, and deferred cleanup), a terminal emission must be guaranteed to have executed. This is a local control-flow property. When the unit delegates, the obligation transfers to the callee's CFG. Crucially, this transfer is still *intrapackage* for the dominant case (F1) and does not require interprocedural flow tracking across package boundaries unless the helper itself is in another package or reached via dynamic dispatch.

### F4 — Goroutine-spawned emissions are a residual gap

If a unit spawns `go emitTrailer(ctx, rec)` and then returns, the emission may execute after the unit's logical completion. Whether this satisfies the trailer-completeness invariant depends on the kernel's attestation model (see vault entry `[[concepts/moment-of-action-freshness]]`). The line did not resolve whether asynchronous emission is semantically equivalent to synchronous emission for freshness purposes. This remains an open thread (see below).

---

## Recommendations

### R1 — Two-tier suppression pass in `hngh-automation`

Do not build a single monolithic interprocedural analyzer. Implement two distinct, composable passes:

**Tier 1 — Intrapackage direct-call resolution (high-confidence suppression).**
For each unit under check, parse the AST with `go/ast` and resolve all same-package function calls via `go/types`. If any resolved callee's body contains a terminal-emission pattern (see R2), suppress the false positive. This is O(local) in cost, requires no cross-package type information, and covers F1.

**Tier 2 — Structural emission-pattern heuristic with fail-safe fallback.**
Define a strict syntactic predicate for what constitutes a terminal emission site (e.g., a call whose resolved name matches `EmitTrailer`, `WriteTrailer`, or a kernel-exported equivalent). If the checked unit delegates to an interface-typed method or a `func`-typed variable, do **not** suppress. Instead, emit a diagnostic: *"Potential delegation via dynamic dispatch; manual verification required."* This preserves soundness (no silent pass on unresolvable paths) at the cost of a residual false-positive rate for dynamic cases, which the line judged acceptable given their expected rarity in `hngh-automation`.

### R2 — Reframe the invariant as local CFG reachability

For each checked unit, build a local control-flow graph. Identify all exit points. A terminal emission must dominate every exit point (i.e., be on every path from entry to any exit). When the unit delegates to a same-package helper, the helper's CFG inherits the obligation: the helper must itself satisfy the dominance property. This is still intrapackage analysis and does not require interprocedural flow tracking.

### R3 — Empirical classification before implementation

Before coding Tier 1, enumerate historical "Trailer Completeness" failures from `hngh-automation` CI/rung logs and classify each:
- Direct same-package call (expected: >80%)
- Interface dispatch
- Goroutine spawn
- Cross-package helper

If the direct-call class dominates as predicted, Tier 1 alone suppresses the bulk of noise. If interface dispatch or goroutine cases are non-trivial, the fail-safe diagnostic in R1-Tier-2 becomes the primary user-facing output and its wording should be tuned accordingly. The line was cut off before this enumeration could be completed; it remains the highest-priority open thread.

### R4 — Do not couple `hngh-automation` to the kernel's internal type graph

The hngh kernel repository (`/home/bricker/Projects/etc/hngh`) defines the emission API, but `hngh-automation`'s checker should depend only on the *exported* emission signatures (the structural pattern in R2), not on the kernel's internal call graph. This keeps the automation repo's analysis self-contained and avoids a build-order dependency where the checker must re-analyze kernel internals on every change.

---

## Open Threads

1. **Empirical false-positive census (R3).** The classification of historical failures was initiated but not completed. Without it, the expected suppression rate for Tier 1 is an estimate, not a measurement. This should be the first action when the line reopens or a successor line inherits this thread.

2. **Goroutine emission semantics (F4).** Whether `go emitTrailer(...)` satisfies the moment-of-action freshness invariant is a kernel-level semantic question, not an analysis-technique question. It requires either a kernel maintainer's ruling or a formal reading of the attestation protocol in `/home/bricker/Projects/etc/hngh`. The vault entry `[[concepts/moment-of-action-freshness]]` frames the freshness recheck but does not resolve the async case.

3. **Cross-package helper delegation.** If a unit in `hngh-automation` calls a helper in a *different* package (e.g., a shared internal utility), Tier 1's intrapackage walk cannot see the emission. The line did not determine how common this pattern is. If it is rare, the fail-safe diagnostic suffices. If it is common, a narrow cross-package points-to analysis over a small set of known helper packages may be warranted without full interprocedural machinery.

4. **Delegated-contract verification boundary.** The vault entry `[[concepts/delegated-contract-verification]]` and the synthesis `[[syntheses/delegated-subagent-steering]]` describe a broader pattern of verifying that delegated work satisfies its contract. The Trailer Completeness check is one instance. Whether the two-tier approach generalizes to other delegation checks in `hngh-automation` (e.g., log-completeness, state-transition completeness) was not explored and could be a successor line.

5. **Go toolchain version sensitivity.** The analysis relies on `go/ast` and `go/types`. Go's type-checking behavior for generics (introduced in Go 1.18) can affect whether an interface method set is fully resolvable at the AST level without full instantiation. The line did not pin the minimum Go toolchain version under which Tier 1's resolution is sound. This should be verified against the `go.mod` in both `hngh-automation` and the kernel repository before implementation.

---

## Resolution Statement

The question resolves to: **intrapackage call-graph analysis, augmented by a structural emission-pattern heuristic with fail-safe diagnostics for dynamic dispatch, is sufficient for accurate false-positive suppression in the dominant case.** Full interprocedural flow-sensitive analysis is not required for `hngh-automation`'s current delegation patterns. The residual gap (dynamic dispatch, goroutine semantics, cross-package helpers) is handled by failing safe—reporting rather than silently passing—which preserves the check's soundness without the cost of a cross-package points-to or CHA implementation.

---

## References

- **This line's prior beats** (research-lines.tsv; state: expanding → contracting). The findings F1–F4 and recommendations R1–R4 are synthesized from the beat material recorded under this line, including the truncated 2026-09-13 beat that established the two-tier strategy and the path-sensitivity reframe.
- **`hngh-automation` repository** — the automation repo where the "Trailer Completeness" check resides and where Tier 1 / Tier 2 suppression would be implemented. Specific file paths within this repository (e.g., the exact checker source file, CI configuration) were not independently verified in this contraction and should be confirmed against the working tree before implementation.
- **`/home/bricker/Projects/etc/hngh`** — the hngh kernel repository, which defines the emission API (`EmitTrailer` or equivalent) and the attestation model. The checker's structural pattern (R2) must match the kernel's exported emission signatures. Internal file paths within the kernel were not cited here as they were not verified in this contraction.
- **Go standard library: `go/ast`, `go/types`** — external, well-documented packages for AST parsing and type resolution. No further citation needed; behavior is specified by the Go language specification and the `go/types` package documentation.
- **Vault: `[[concepts/moment-of-action-freshness]]`** — frames the attestation freshness recheck; relevant to open thread 2 (goroutine semantics).
- **Vault: `[[concepts/delegated-contract-verification]]`** — broader delegated-contract pattern; relevant to open thread 4.
- **Vault: `[[syntheses/delegated-subagent-steering]]`** — synthesis on delegated subagent steering; contextual for the delegation patterns under analysis.
- **Vault: `[[sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled]]`** — observation record for the overnight harness build; provides temporal context for when the check was enabled.
- **Vault: `[[sources/obs-2026-08-25-post-rung-11-documentation-refresh-attribution-record-and-au]]`** — post-rung documentation refresh; may contain attribution records relevant to the false-positive census (R3).
- **Vault: `[[sources/async-proof-pattern-for-long-drop-ins]]`** — async proof pattern for long-running drop-ins; potentially relevant to goroutine emission semantics (open thread 2).

*External claims not verified in this contraction:* The specific Go toolchain version constraints for generics-aware type resolution (open thread 5) would require consulting the `go.mod` files in both repositories and the Go release notes. The exact historical false-positive distribution (R3) requires access to CI/rung logs, which were not available in this beat. Both are flagged as open rather than asserted.
