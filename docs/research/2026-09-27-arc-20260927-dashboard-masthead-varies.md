# How should edition.masthead.expansion vary per edition without colliding across the editions history window?

Status: crystallized 2026-09-27 from research line `arc-20260927-dashboard-masthead-varies`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-arc-20260927-dashboard-masthead-varies.md.

# research transition 2026-09-27 — final contraction (lasting record)

_line: How should edition.masthead.expansion vary per edition without colliding across the editions history window? | state: contracting -> **contracted (closed)** | transition: crystallize final record_

> **Verification status up front.** No filesystem read of this repository or of the hngh kernel at `[redacted path] was possible in this transition — the same limitation the prior contraction disclosed. Accordingly, this record asserts **no concrete file paths inside either repository**. Every kernel-layout-dependent claim is marked *unverified*. The vault pointers from prior art are cited by name as given; their contents were not re-read here. This is the line's single most important caveat, and it is recorded as Open Thread T1.

---

## 1. Line summary

The line asked how `edition.masthead.expansion` should vary per edition without editions colliding across the history window. The crystallized answer: **make the value a pure function of edition identity, never a stored shared value; namespace any materialization by edition; capture each edition's value into the per-edition history record.** Collisions across a history window happen when N editions share one mutable slot. The fix is architectural (remove the slot), not procedural (coordinate access to the slot).

**Core invariant:** `expansion = f(edition identity)` — where identity is edition ID, timestamp, or content hash. The masthead may be shared configuration across editions; the expansion value must not be.

## 2. Findings

**F1. Shared-parameter drift across surfaces is a documented failure mode in this project family.** Grounds R1 and R5. Source: `[[sources/verdict-rule-drift-two-surfaces]]`. *Verification: vault pointer as supplied; entry not re-read this transition.*

**F2. Path collisions across worker wakes are a documented failure mode for serialized/materialized state.** Any value written to disk or a shared store without identity in its path will eventually collide. Grounds R2. Source: `[[sources/obs-2026-08-26-hngh-worker-wake-scratch-store-path-collides-across-wakes]]`. *Verification: vault pointer as supplied.*

**F3. A history-collection mechanism exists as prior art and is the natural home for per-edition time-varying values.** Grounds R3. Sources: `[[entities/history-collector]]`, `[[sources/SRC-2026-08-18-006]]`. *Unverified: the collector's actual schema, retention, and whether it captures per-edition config. The vault entry is a pointer, not a spec.*

**F4. Drift must be confirmed empirically before being assumed.** Standing lesson; grounds R4 and forbids implementing speculative fixes blind. Source: `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]`.

**F5 (negative finding).** Across this line's entire history, no transition has read the hngh kernel. The location, type, and materialization behavior of `edition.masthead` remain unknown. All recommendations below are therefore conditional, and each names its dependency explicitly.

## 3. Recommendations (final)

**R1. Derive, don't assign.** Bind `edition.masthead.expansion` to edition identity (ID / timestamp / content hash) as a pure function. Drift becomes impossible by construction — there is nothing to drift. *Dependency: how editions are identified in the kernel (T1).*

**R2. Namespace any materialized path by edition.** If the value is ever serialized or stored, the edition identifier goes in the path/key. Direct transfer of the scratch-store collision lesson (F2). *Dependency: whether the value is materialized at all (T2); treat serialization as guilty until inspected.*

**R3. Record expansion as a per-edition historical artifact.** Whatever value an edition used is captured with that edition's context via the history-collection path, so the history window holds N isolated records instead of one contested slot. *Dependency: collector schema and retention (T3).*

**R4. Instrument before fixing.** Determine whether collision occurs in-memory, at serialization, or at storage *before* implementing. One instrumentation pass beats two speculative fixes (F4). R1 covers the in-memory case, R2 the storage case — R4 decides which are actually needed.

**R5. No global default with per-edition overrides.** Overrides of a shared value are exactly where drift breeds (F1). If a default is needed, it lives as a fallback *inside* the derivation function (R1), not as a separately stored value.

**Sequencing:** T1 → R4 → R1 → (R2 only if R4 shows a storage path) → R3.

## 4. Open threads

- **T1 (blocking).** Locate where `edition.masthead` — and specifically `.expansion` — is defined and read in `[redacted path] Resolves every *unverified* tag above. This is the first action for any successor line.
- **T2.** Run the R4 instrumentation check to classify the collision surface.
- **T3.** Confirm the history collector's schema/retention in the kernel and define the "editions history window" concretely (how many editions, what eviction policy).
- **T4 (conceptual).** Distinguish **isolation** from **uniqueness**. R1 guarantees each edition's value is preserved separately; it does *not* guarantee two editions derive different values. If distinct expansions across the window are a requirement (e.g., visual differentiation in the masthead), the derivation needs a tie-breaker or the requirement needs re-examination. The line's question as posed is about isolation; uniqueness was never established as a requirement.
- **T5.** The `[[sources/chartlibrary-io-developers-api]]` prior-art pointer appears unrelated to this line; no finding or recommendation draws on it. Recorded so future transitions don't re-investigate it.

## 5. Explicit non-claims

- No path inside this repository or the hngh kernel is asserted to exist, beyond `research-lines.tsv` (named in the line state) and the kernel root `[redacted path] (named in the task).
- No external sources were consulted. Claims about derivation-based parameterization rest solely on the internal failure-pattern evidence (F1, F2), not on external validation.

## References

- `research-lines.tsv` — line state, this repository
- `[redacted path] — hngh kernel repository root (not read this transition)
- `[[sources/verdict-rule-drift-two-surfaces]]` — llm-wiki vault (read-only pointer)
- `[[sources/obs-2026-08-26-hngh-worker-wake-scratch-store-path-collides-across-wakes]]` — llm-wiki vault
- `[[entities/history-collector]]` — llm-wiki vault
- `[[sources/SRC-2026-08-18-006]]` — llm-wiki vault (History Collector – Agent Memory Distillation Pipeline)
- `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]` — llm-wiki vault
- Prior material on this line: expansion beat and contraction beat, 2026-09-27

_Line closed in contracted state. Successor work begins at T1._
