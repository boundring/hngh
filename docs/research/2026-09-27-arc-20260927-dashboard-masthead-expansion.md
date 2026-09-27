# Where should the procedural H.N.G.H. expansion generator live so newspaper.json edition.masthead.expansion carries four fully spelled words with initials H N G H?

Status: crystallized 2026-09-27 from research line `arc-20260927-dashboard-masthead-expansion`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-arc-20260927-dashboard-masthead-expansion.md.

# research beat — line crystallization

_line: Where should the procedural H.N.G.H. expansion generator live so newspaper.json edition.masthead.expansion carries four fully spelled words with initials H N G H? | state: contracting -> crystallized (closed)_

## Grounding note

This transition runs without mounts to the working repository, `research-lines.tsv`, the hngh kernel repository (`[redacted path] or the llm-wiki vault. Consistent with the prior material's discipline, I cite only paths the prior material explicitly named and flag everything else as unverified rather than asserting it. Nothing below invents a file path.

---

## Final structured summary — lasting record

### Question

Where should the procedural generator that produces the four-word H.N.G.H. masthead expansion live, such that `newspaper.json` → `edition.masthead.expansion` carries four fully spelled words whose initials are H, N, G, H?

### Findings

1. **The core question dissolved on inspection.** The guarantee "four words, initials H-N-G-H" is a *data contract*, not a placement property. Prior material established that "the guarantee can be encoded as a validator regardless of where generation happens." Once the invariant is checkable at the data layer, generator placement becomes a matter of repository hygiene, not correctness. This is the line's principal finding.

2. **Generation and validation are different artifact kinds and should not co-locate.** The generator is a process artifact (tooling); the validator is a contract artifact (it must travel with the data or be trivially discoverable from it). Conflating them couples consumers of `newspaper.json` to the generator's location for no benefit.

3. **The kernel repository is the natural home for the generator — conditionally.** The prior material names `[redacted path] as the hngh kernel repository and notes it already hosts procedural tooling design work (per the llm-wiki synthesis `syntheses/hngh-procedural-tooling-design-2026-08`). Placing the generator in that repository's tooling layer keeps it alongside sibling hngh tooling. This is conditional on the tooling layer existing as described — **unverified in any transition of this line.**

4. **Representation of `expansion` dominates every other sub-decision.**
   - If `expansion` is **structured** (an array of four words), the invariant is self-enforcing at the data level; the validator is trivial (length 4, initials H/N/G/H in order); generator placement is nearly irrelevant.
   - If `expansion` is a **single string**, the validator needs a tokenization policy (whitespace split? punctuation handling? hyphenation?), which couples the validator to that policy and makes the *validator's* placement consequential even though the generator's still is not.
   - The current representation in `newspaper.json` was never read during this line — **unverified.**

5. **Validator placement: sibling-to-data beats centralized.** A validator adjacent to `newspaper.json` (e.g., a schema or validator module in the same directory) is invocable by any consumer without knowledge of the generator. A centralized validation directory in the kernel repo is a reasonable later consolidation but adds an unnecessary cross-repository dependency for a single contract today.

### Recommendations (final)

1. **Resolve representation first.** Prefer a structured `expansion` (array of exactly four words). This collapses most of the remaining design space.
2. **Place the generator in the hngh kernel repository's tooling layer** (`[redacted path] exact subdirectory to be confirmed against that repo's actual layout — unverified here).
3. **Place the validator adjacent to the data** (same directory as `newspaper.json`, or a schema reference from it), so the contract is checkable without importing the generator.
4. **Encode the invariant as the contract, not as generator behavior.** The generator may produce any candidate expansion; acceptance is decided solely by the validator. This keeps the generator free to be procedural, randomized, or template-based without threatening the guarantee.
5. **Record the decision in the line ledger** (`research-lines.tsv`) with state `crystallized`.

### Open threads (for any future line, not blockers to closing this one)

- **Unverified file state.** No transition of this line read `newspaper.json`, so the current content and representation of `edition.masthead.expansion` — and whether the file exists at all — remain unconfirmed. A host with mounts should read it before implementing.
- **Kernel tooling layout.** The exact path for the generator inside `[redacted path] was never confirmed against the repository.
- **Prior-art content.** The vault entries `sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha` and `syntheses/hngh-procedural-tooling-design-2026-08` were cited by pointer only; their content may refine recommendation 2.
- **Tokenization policy (only if string representation is kept).** If a future implementer chooses a single-string `expansion`, the tokenization policy must itself be versioned somewhere; this line did not decide where.
- **Wordlist provenance.** A procedural generator needs a source of candidate H/N/G/H words. Where that wordlist lives (and whether it is hand-curated or derived) was out of scope and untouched.

### Verdict

**Crystallized.** The line's question is answered at the level the evidence supports: placement of the generator is a hygiene decision (kernel repo tooling layer), correctness lives in a data-adjacent validator, and representation should be resolved before implementation. All remaining threads are verification steps, not open design questions. Recommended ledger transition: `contracting → crystallized`.

---

## References

- `research-lines.tsv` — research line ledger (named in contract; contents unverified in this transition)
- `[redacted path] — hngh kernel repository (path given in contract; layout unverified)
- `newspaper.json` — target data file, `edition.masthead.expansion` field (named in contract; existence and current contents unverified)
- llm-wiki vault: `sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha` — prior-art pointer (read-only pointer only; content not read in this line)
- llm-wiki vault: `syntheses/hngh-procedural-tooling-design-2026-08` — prior-art pointer (read-only pointer only; content not read in this line)
