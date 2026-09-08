# The Cistern roadmap carries DEFERRED items (DESIGN-SPEC §6, resolved outside the roadmap) — what are they, which are actionable now, and which would Hngh's machinery (disposition spine, research beats, context packs) contribute to?

Status: crystallized 2026-09-08 from research line `cistern-roadmap-deferred`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-cistern-roadmap-deferred.md.

# Research Line Record: Cistern DEFERRED Items ∩ Hngh Machinery

**Line:** The Cistern roadmap carries DEFERRED items (DESIGN-SPEC §6, resolved outside the roadmap) — what are they, which are actionable now, and which would Hngh's machinery (disposition spine, research beats, context packs) contribute to?
**Lifecycle State:** Contracting (Final Summary)
**Date:** 2026-09-08

## Executive Summary

This research line attempted to map specific deferred items in the Cistern DESIGN-SPEC §6 against actionable capabilities within the Hngh kernel. The investigation reached a **hard stop due to missing ground-truth data**. The primary obstacle was not analytical complexity, but the absence of the source documents (Cistern DESIGN-SPEC and Hngh repository contents) from the research context.

Consequently, this line does not yield a factual mapping of deferred items. Instead, it yields a **meta-finding regarding the research infrastructure itself**: current "research beats" cannot reliably ground claims when context packs contain only pointers/titles rather than file contents. The final contribution of this line is a set of recommendations to harden the Hngh machinery against ungrounded speculation, specifically by enforcing content-level context injection and adding provenance tracking to disposition records.

## Findings

### 1. Failure Mode: Title-Only Context Leads to Unverified Speculation
The prior expansion beat generated hypotheses regarding Cistern deferred items (e.g., distillation pipelines, Emacs bindings, injection defenses). However, these were derived from vault note *titles* (e.g., `[[cases/cistern-emacs-rewrite]]`) rather than the actual text of DESIGN-SPEC §6.
*   **Observation:** When a research beat is asked to "ground every claim" but only has access to metadata/titles, it either hallucinates structural details or must disclaim all findings.
*   **Result:** The hypotheses generated in the expansion phase are classified as `unverified` and are not considered established facts for downstream lines.

### 2. Hngh Machinery Gap: Lack of Provenance Enforcement
The current disposition spine and beat pipeline do not explicitly distinguish between claims based on verified file content versus those inferred from titles or external knowledge.
*   **Observation:** Without a schema field to mark grounding status, unverified speculation can be mistaken for established findings in the final record.
*   **Implication:** The machinery needs a lightweight schema addition to track *how* a claim was derived, not just *what* the claim is.

### 3. Actionable Core: Infrastructure Hardening
While the specific Cistern items remain unknown, the failure of this line points to an immediate, actionable improvement in Hngh's own research automation:
*   **Context Pack Assembler:** Must inline file contents (or bounded excerpts) for any referenced path/vault pointer. Title-only references must be flagged as `unresolved`.
*   **Beat Precondition:** A research line that names a specific document (e.g., "DESIGN-SPEC §6") should not execute unless that document's content is present in the context pack.

## Recommendations

### 1. Enforce Content-Level Context Injection (High Leverage)
**Action:** Modify the Hngh context-pack assembler to detect file paths or vault pointers in the prompt/line definition.
*   If a path exists, inline the relevant excerpt.
*   If only a title is available, mark it `unresolved` and prevent the beat from proceeding if the line's question depends on that specific content.
*   **Rationale:** This directly addresses the failure mode observed in this line. It ensures future beats are grounded in actual text, not metadata.

### 2. Add Grounding Status to Disposition Schema (Medium Leverage)
**Action:** Extend the disposition spine record schema to include a `grounding` field for each claim/finding.
*   Values: `verified` (file content seen), `inferred` (structural reasoning from verified material), `unverified` (title-level or external).
*   **Rationale:** This allows the research process to retain speculative hypotheses without contaminating the factual record. It makes the "partial grounding" state explicit and manageable.

### 3. Define Beat Precondition for Document-Dependent Lines
**Action:** Implement a check in the beat runner: if the line's question references a specific document section (e.g., "§6"), verify that the content of that section is in the context pack before execution. If not, transition the line to `blocked-on-input`.
*   **Rationale:** Prevents wasted compute on ungrounded speculation and clearly signals what input is missing.

### 4. Re-Enter Cistern Analysis with Grounded Input
**Action:** Do not attempt to resolve the original question (What are the DEFERRED items?) until a targeted read of `DESIGN-SPEC §6` is performed and its content injected into a new beat's context pack.
*   **Rationale:** The current hypotheses (A, C, D) are dropped from this line's record. If future grounded input confirms them, they should be re-entered as `verified` findings in a new or resumed line.

## Open Threads

1.  **Cistern DESIGN-SPEC §6 Content:** The actual list of deferred items remains unknown. This requires a direct file read from the Cistern repository, which is not currently accessible in this context.
2.  **Hngh Repository Structure:** The specific files implementing "disposition spine," "research beats," and "context packs" within `/home/bricker/Projects/etc/hngh` have not been verified. Recommendations 1 and 2 assume these components exist as described; their exact implementation paths need confirmation to apply the schema changes.
3.  **Existing Provenance Fields:** It is unknown if Hngh-automation already has a partial grounding/provenance field. Recommendation 2 may be partially implemented or redundant.

## References

*Note: The following references are cited based on the prior material's context and standard repository structures. Direct verification of file contents was not possible in this contraction phase.*

1.  **Cistern Repository:**
    *   `DESIGN-SPEC` (Section 6): *Content unavailable.* This is the primary missing input for resolving the line's factual core.
    *   `cases/cistern-emacs-rewrite`: *Title only.* Referenced in prior beat; content not verified.
    *   `sources/cistern-project-findings`: *Title only.* Referenced in prior beat; content not verified.

2.  **Hngh Kernel Repository (`/home/bricker/Projects/etc/hngh`):**
    *   *Paths for "disposition spine," "research beats," and "context packs" implementations:* *Unverified.* The prior material references these concepts but does not cite specific file paths (e.g., `src/disposition/spine.ts`, `tools/context-pack.js`). These need to be located to implement Recommendations 1 and 2.

3.  **External Sources (Referenced in Prior Art, Unverified):**
    *   CaMeL: Defeating Prompt Injections by Design (`sources/SRC-2026-08-24-002`)
    *   Autonomous Development Control (Evidence Ledger Design) (`sources/SRC-2026-08-24-021`)

## Conclusion

This line is **contracted** with a focus on infrastructure improvement rather than factual resolution. The primary output is the identification of a critical gap in Hngh's research automation: the lack of enforced content-level grounding. By implementing the recommended schema and assembler changes, future research lines will be able to distinguish between verified findings and speculative hypotheses, preventing the contamination of the knowledge base with ungrounded claims. The original question regarding Cistern DEFERRED items remains **open** and requires a new beat with grounded input from `DESIGN-SPEC §6`.
