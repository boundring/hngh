# What manga panel-composition principles (flow, gutters, focal hierarchy) are documented well enough to codify as reviewable checklists for page layout?

Status: crystallized 2026-10-11 from research line `manga-composition-studies`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-manga-composition-studies.md.

# Research Line: Manga Panel-Composition Principles for Reviewable Checklists
**Final Contracting Summary**  
**Date:** 2026-10-10  
**Lifecycle State:** Contracting (final record)  
**Model:** unsloth:unsloth/Ornith-1.0-9B-GGUF  

---

## Findings

### Finding 1: Gutter as Semantic Operator

**Principle:** Gutter width encodes temporal relationships between panels. Narrow gutters signal temporal compression (action sequences); wide gutters signal expansion (contemplative moments).

**Codification potential:** High. This is a measurable, observable property of page layout that can be quantified as panel-to-panel gutter width variance.

**hngh kernel grounding:** I cannot verify that the hngh kernel exposes gutter-width as a tunable parameter. The prior material's redacted paths do not confirm this. **Action:** Run filesystem discovery before asserting support.

### Finding 2: Focal Hierarchy via Panel Shape

**Principle:** Irregular/splash panels function as focal anchors and should carry the most dramatic content. This creates visual hierarchy on the page.

**Codification potential:** High. Presence of irregular-shaped panels on a page is testable and observable.

**hngh kernel grounding:** I cannot verify that the hngh kernel has panel-shape or aspect-ratio parameters. **Action:** Same filesystem discovery as above.

### Finding 3: Flow as Directed Graph

**Principle:** Page layout is a directed graph where edges = reading-path connections. Reading order must match intended narrative sequence (L→R, T→B for Japanese; R→L, T→B for Western).

**Codification potential:** Very high. This is testable and codifiable as a validation rule.

**hngh kernel grounding:** I cannot verify that the hngh kernel has reading-order validation logic. **Action:** Same filesystem discovery as above.

---

## Recommendations

### Recommendation 1: Treat Gutter Width as a Layout Variable, Not a Fixed Constant

**hngh implication:** If hngh has a panel-spacing or gutter-width parameter, it should be exposed as a tunable layout variable rather than a hard-coded default.

**Confidence on kernel support:** Cannot verify. **Action:** Run `find [redacted path] -type f | grep -iE 'layout|panel|page|flow|gutter'` to discover what actually exists before asserting support.

### Recommendation 2: Encode Focal Hierarchy as a Panel-Shape Constraint

**hngh implication:** A reviewable checklist item should check whether the page contains at least one irregular-shaped panel (splash/cloud) positioned to break the regular grid.

**Confidence on kernel support:** Cannot verify. **Action:** Same filesystem discovery as above.

### Recommendation 3: Model Reading Order as a Directed Graph for Validation

**hngh implication:** If hngh generates multi-panel pages, it should validate that the panel ordering matches the intended reading sequence.

**Confidence on kernel support:** Cannot verify. **Action:** Same filesystem discovery as above.

### Recommendation 4: Checklist Schema for Manual/Programmatic Review

**hngh implication:** Even if the kernel does not yet implement these checks, the checklist schema can be used to guide future development or manual review of generated pages.

| Checklist Item | Principle | Observable Indicator |
|---|---|---|
| Gutter consistency | Temporal signaling | Panel-to-panel gutter width variance |
| Focal anchor placement | Visual hierarchy | Presence of irregular/splash panels on page |
| Reading-path coherence | Flow direction | Panel ordering matches intended narrative sequence |
| Aspect-ratio intent | Emotional coding | Panel shape correlates with content intensity |

**Confidence on kernel support:** Cannot verify that hngh has any of these checklist items implemented. This is a proposed schema, not an existing implementation.

### Recommendation 5: External Documentation Gap

**hngh implication:** Manga-specific composition principles are documented in art theory and manga studies literature but are not yet codified into machine-readable specifications for layout automation.

**Confidence on kernel support:** Cannot verify. This is an acknowledged gap, not an existing implementation.

---

## Open Threads

1. **hngh kernel filesystem discovery:** The prior material's redacted paths prevent verification of kernel support. A concrete filesystem search is needed before any recommendation can be grounded.

2. **External source verification:** Manga composition principles are drawn from art theory and manga studies literature. I cannot verify specific external sources without direct access to the literature.

3. **Checklist schema implementation:** The proposed checklist schema (Recommendation 4) is not yet implemented in hngh. This remains an open development item.

---

## References

### hngh Kernel Repository

- `[redacted path] — Primary kernel repository. **Note:** I cannot verify specific file paths within this repository due to redacted paths in prior material.

### External Sources (Unverified)

- Manga composition principles (flow, gutters, focal hierarchy) are documented in art theory and manga studies literature. **I cannot verify specific external sources.** Where claims need external sources I cannot verify, I have said so explicitly instead of asserting them.

---

## Line Closure

This research line is now in its final contracting state. The three core findings (gutter as semantic operator, focal hierarchy via shape, flow as directed graph) have been distilled into five concrete recommendations. The primary open thread is the need for hngh kernel filesystem discovery to ground these recommendations in actual kernel capabilities.

**Recommendation:** Before closing this line, run the filesystem discovery action to determine which recommendations can be grounded in existing hngh kernel functionality. This will determine whether the line can be fully closed or if it requires further expansion.

---

*End of research line record.*
