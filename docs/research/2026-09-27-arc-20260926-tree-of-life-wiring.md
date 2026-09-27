# wire automation/research-tree.tsv hierarchy into research-routes/graph-data and a dashboard tree view -- which queries and guards does the tree contract need?

Status: crystallized 2026-09-27 from research line `arc-20260926-tree-of-life-wiring`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-arc-20260926-tree-of-life-wiring.md.

# Research Line — Final Crystallized Record

**Line:** wire `automation/research-tree.tsv` hierarchy into `research-routes/graph-data` and a dashboard tree view — which queries and guards does the tree contract need?
**Lifecycle trajectory:** expanding → contracting → **crystallized** (this transition)
**Beats on record:** 2026-09-27 (two contractions); this transition is the final record.

---

## Epistemic status (read first)

Like the prior beat, this transition **could not open the automation repository or the hngh kernel repository on disk**. No file path in this record has been confirmed in this transition. The paths `automation/research-tree.tsv`, `research-lines.tsv`, `research-routes/graph-data`, and `[redacted path] are **line-stated locations** carried through the line's history, not verified facts. All schema content of the TSV (column names, row structure) remains **hypothesis**. This record therefore presents the contract as a set of requirements each paired with its verification step. No claim below relies on external sources; none are cited.

---

## Findings

**F1. Authority direction is the central architectural decision.** The line converged on: the TSV is the authoritative hierarchy; `graph-data` is a *derived, reproducible projection*. This makes drift detectable by re-projection-and-diff rather than inference. (Unverified precondition: `graph-data` is machine-generated, not hand-edited — see OT1.)

**F2. Provenance must survive projection.** Every graph edge derived from the hierarchy needs a provenance field (source `node_id` + `parent_id`, ideally row number) so any rendered dashboard edge traces back to a TSV line. Without this, tree↔graph divergence is undiagnosable.

**F3. Drift is a known failure mode in this system, and the failure shape is specific.** The vault lesson `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]` documents drift confirmation as a recurring problem. The dangerous shape is a *clean-looking view that does not match reality* — which is exactly what suppressing drifted nodes produces. Hence: annotate, never silently suppress.

**F4. Guards belong in the query path, not the render layer.** A dashboard tree view should be a dumb renderer of guarded query output. Validation placed in the view is bypassable and duplicated; validation at projection/query time is single-point and testable.

---

## The tree contract (the line's answer)

### Required schema — five columns (minimum)

| Column | Purpose |
|---|---|
| `node_id` | unique, stable identifier |
| `parent_id` | hierarchy edge; empty for roots |
| `edge_type` | semantic class of the link (`extends`, `depends_on`, …) so graph-data does not collapse distinct relationships into untyped edges |
| `declared_state` / `state_hash` | the value the drift guard compares against live host state |
| `updated_at` | staleness and drift-detection timestamp |

### Schema guards — three, run at projection time

1. **Uniqueness** — reject duplicate `node_id`. Hard fail.
2. **Acyclicity** — reject any `parent_id` cycle. Hard fail; a tree view cannot render cycles, so this is structural, not cosmetic.
3. **Orphan** — every `parent_id` must resolve to an existing `node_id`. Unresolved references are **flagged, never silently dropped** — silent dropping is how hierarchy drift hides.

### Drift guard — one, run at query time

- Compares per-node `declared_state`/`state_hash` against live host state at query time.
- Emits a per-node `drift_status` field **in the query response**.
- Drifted nodes render annotated with a drift flag; suppression is opt-in only.

### Required queries — six

| Query | Serves |
|---|---|
| `roots()` | tree entry points |
| `children(node_id)` | lazy expansion in the dashboard view |
| `path_to_root(node_id)` | breadcrumbs / ancestor context |
| `subtree(node_id, depth)` | bounded expansion; also the projection-diff unit |
| `drift_status(node_id \| subtree)` | guard output, per F3/F4 |
| `provenance(edge)` | edge → TSV row traceback, per F2 |

---

## Recommendations (carried forward, sharpened)

- **R1.** Single authority, derived projection; projection must be a pure function of the TSV. *Verify the graph-data generator exists before committing (OT1).*
- **R2.** Adopt the five-column schema and three schema guards above.
- **R3.** Drift guard in the query path; annotation by default; suppression opt-in.

---

## Open threads

- **OT1 (blocking for R1):** Locate the generator of `research-routes/graph-data` in the hngh kernel repo (`[redacted path] If none exists — if graph-data is hand-maintained — the authority direction must be reconsidered.
- **OT2:** Confirm the actual on-disk schema of `automation/research-tree.tsv`. Everything in the schema table above is a requirement, not a description.
- **OT3:** Resolve the relationship between `research-lines.tsv` (line state, named in this transition's brief) and `automation/research-tree.tsv` (hierarchy). Are they one file, joined files, or parallel authorities? The vault lesson `[[sources/LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu]]` suggests the lines schema has itself been a research question.
- **OT4:** The prior beat was truncated mid-sentence at the end of R3; its remaining content (if any existed) is unrecoverable from this line's record.
- **OT5:** `edge_type` vocabulary is unspecified. The contract needs an enumerated set before graph-data can type its edges.

---

## References

*Line-stated, unverified in this transition:*
- `automation/research-tree.tsv` — hierarchy source (existence and schema unconfirmed)
- `research-lines.tsv` — line state file (named in transition brief)
- `research-routes/graph-data` — projection target (generator unlocated)
- `[redacted path] — hngh kernel repository (not opened this transition)

*Prior art (llm-wiki vault, read-only pointers):*
- `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]` — drift confirmation failure mode (basis for F3/R3)
- `[[sources/LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu]]` — lines schema uncertainty (basis for OT3)
- `[[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]]` — hngh automation lesson (not incorporated; unread this transition)
- `[[sources/LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca]]` — file-path uncertainty lesson (reinforces this record's epistemic stance)
- `[[concepts/delegated-contract-verification]]` — contract verification concept (relevant to OT1/OT2 verification steps)
- `[[sources/SRC-2026-08-24-020]]` — Hngh Run Contract (candidate template for formalizing the tree contract)
