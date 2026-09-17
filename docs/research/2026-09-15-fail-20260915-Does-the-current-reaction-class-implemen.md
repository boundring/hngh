# Does the current `reaction` class implementation in `~/Projects/etc/hngh/src/reaction.rs` (or equivalent) contain paths that produce unbounded or dynamically named outputs, which would necessitate a structural split under R1?

Status: crystallized 2026-09-15 from research line `fail-20260915-Does-the-current-reaction-class-implemen`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260915-Does-the-current-reaction-class-implemen.md.

# Final Structured Summary — R1 Output-Surface Classification for `reaction`

**Line:** Does the current `reaction` class implementation in `~/Projects/etc/hngh/src/reaction.rs` (or equivalent) contain paths that produce unbounded or dynamically named outputs, which would necessitate a structural split under R1?
**Lifecycle State:** Contracting → Finalized

## Findings
The line reduces to a single binary decision regarding the output-producing surface of the `reaction` class: whether any reachable path emits outputs whose names or counts are not fixed at compile time. 

- **Decision Rule Established:**
  - **CLOSED**: No structural split required. Every output name derives from a closed set (`&'static str`, enum variants, const arrays, fixed lookup tables) and every output collection has a proven fixed length, capacity, or bounded source.
  - **OPEN**: Structural split required under R1. Any path constructs output names at runtime from an unbounded source (e.g., `format!` with non-static inputs, dynamic string concatenation), or any output collection can grow without a proven bound (e.g., unbounded `Vec`/`HashMap` expansion).

- **Verification Status:** I cannot directly access the filesystem or inspect `~/Projects/etc/hngh/src/reaction.rs` from this environment. Consequently, the actual classification of the `reaction` class's output surface remains unverified. The presence or absence of dynamic string construction or unbounded collection growth is currently an open empirical question requiring local inspection on an idle host.

## Recommendations
1. **Confirm Authoritative Path:** On an idle host with access to `~/Projects/etc/hngh`, verify whether `src/reaction.rs` is the correct and current location of the `reaction` class, or if it has been refactored into an equivalent module.
2. **Execute Inspection Protocol:** Scan the `reaction` class and all reachable code paths (constructors, methods, trait impls, closures, helpers) for:
   - **Dynamic naming idioms:** `format!`, `write!`, `String::push_str` with non-static variables, or any runtime string allocation.
   - **Unbounded growth idioms:** `Vec::push`/`extend` without capacity limits, `HashMap`/`BTreeMap` insertions with unbounded key spaces, or iterators that lack strict bounds (e.g., `.take(N)` or proven source exhaustion).
3. **Record Classification:** Apply the decision rule continuously as the line is inspected. If any dynamic/unbounded path is found, mark the line as **OPEN** and document the specific paths requiring structural split under R1. If all outputs are statically named and strictly bounded, mark as **CLOSED**.

## Open Threads
- The empirical classification of the `reaction` class's output surface (CLOSED vs. OPEN).
- If classified as OPEN: The precise architectural boundaries for the structural split required to isolate dynamic/unbounded output paths from the core `reaction` logic.

## References
- `~/Projects/etc/hngh` — Root of the hngh kernel repository.
- `src/reaction.rs` — Path named in the research line as the target implementation; existence and contents require local verification on an idle host.
- `research-lines.tsv` — State tracking file for this continuous research process.
