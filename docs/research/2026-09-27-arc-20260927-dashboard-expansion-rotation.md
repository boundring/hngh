# How should broadsheet-view.js carry a rotation table of at least N spelled H.N.G.H. expansions so the masthead varies durably?

Status: crystallized 2026-09-27 from research line `arc-20260927-dashboard-expansion-rotation`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-arc-20260927-dashboard-expansion-rotation.md.

# Crystallization: H.N.G.H. Masthead Rotation Table

_line: How should broadsheet-view.js carry a rotation table of at least N spelled H.N.G.H. expansions so the masthead varies durably? | state: contracting -> **closed (crystallized)**_

---

## Honesty preamble (load-bearing, retained in the final record)

No beat on this line ever had verified filesystem access. The path `[redacted path] was supplied by the process prompt; `broadsheet-view.js` was named in the line's question but **its location within any repository was never confirmed**; the H.N.G.H. expansion grammar (`[Adjective] [Noun] [Verb] [Object]`) was a hypothesis, never extracted from source. This summary preserves that epistemic status explicitly rather than laundering it. Every recommendation below is conditional on a verification pass that has not yet occurred.

## Findings (final)

**F1 — Separation of concerns is the line's core result.**
The view should carry *no* rotation table at all, despite the line's phrasing. The durable answer to "how should broadsheet-view.js carry a rotation table" is: **it shouldn't** — the table belongs to the hngh kernel; the view holds only rendering, cycle-scoped caching, and a hardcoded fallback (the literal string "H.N.G.H.") so a dead kernel never blanks the masthead. The question contained a false premise, and resolving that is the line's main contribution.

**F2 — The N floor is a rule, not a number.**
`N ≥ rotation period in hours`, with an absolute floor of 24, enforced at **kernel startup** (fail loudly), never at render time. The specific integers (24h/48h) from earlier beats were illustrative, not observed configuration. If cadence becomes host-aware, N must be calibrated against the *longest* per-host interval.

**F3 — Token storage beats string storage, conditionally.**
Storing token pools + a template gives O(tokens) storage for O(compositions) expansions and makes "at least N" auditable as a property of the composition space. **But** this collapses to a plain string table if the actual expansions are non-compositional (fixed phrases, in-jokes). The grammar hypothesis must be confirmed against kernel source before any token schema is written.

**F4 — Dropped as premature.**
Versioning/migration of the table schema; specific N integers; any cadence-aware scheduling logic in the view. A single-schema JSON artifact needs no migration story yet.

## Recommendations (ordered, for hngh-automation)

1. **Verification pass first (blocking):** locate `broadsheet-view.js`; enumerate the kernel's existing HTTP/static-serving surface; extract the actual expansion definitions and record the real grammar. Nothing else on this line should merge before this.
2. **Define the kernel↔view contract:** endpoint or served JSON artifact, schema, cache headers. Choice between "dedicated endpoint" vs "served JSON file" is ungrounded until R1 completes.
3. **Implement kernel-side:** table (tokens+template *or* strings, per R1 outcome), startup-time N validation, rotation cadence.
4. **Implement view-side:** fetch, per-cycle cache, verbatim render, hardcoded `"H.N.G.H."` fallback.

## Open threads (for successor lines)

- **T1:** What is the actual H.N.G.H. expansion grammar in the kernel source? (Blocks F3's branch decision.)
- **T2:** What rotation cadence does hngh-automation target, and is it host-aware? (Sets the concrete N.)
- **T3:** Does the kernel already serve static JSON or HTTP endpoints the view could consume? (Resolves R2's mechanism choice.)
- **T4:** If expansions prove non-compositional, is a curated string table of size N acceptable as the permanent design, or is curated-plus-generative hybrid wanted? (Deferred design question; do not force the grammar angle.)

## References

Paths named by the line or process prompt; **none verified in-session**:

- `[redacted path] — hngh kernel repository (existence asserted by prompt, not confirmed)
- `broadsheet-view.js` — the view under discussion (location within any repo never established)
- `research-lines.tsv` — line state ledger for this research process
- Prior-art pointers (llm-wiki vault, read-only): `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]`; `[[sources/async-proof-pattern-for-long-drop-ins]]`

No external sources were consulted or are required; where verification was needed and impossible, that is stated above rather than asserted around.

_line closed; reopening condition: completion of the R1 verification pass, which converts T1–T3 from open threads into groundable facts._
