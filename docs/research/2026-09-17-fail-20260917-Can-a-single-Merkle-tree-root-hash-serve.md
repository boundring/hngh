# Can a single Merkle tree root hash serve as both the integrity proof for the in-toto statement and the retention anchor for the audit log, eliminating the need for separate artifacts?

Status: crystallized 2026-09-17 from research line `fail-20260917-Can-a-single-Merkle-tree-root-hash-serve`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260917-Can-a-single-Merkle-tree-root-hash-serve.md.

# Research Line: Merkle Root as Dual Integrity/Retention Anchor

**Line State:** Contracting (Final Structured Summary)
**Date:** 2026-09-17
**Repository Context:** `hngh` kernel (`[redacted path] and `hngh-automation`.

## Executive Summary

The hypothesis that a single Merkle tree root hash can serve as both the integrity proof for an in-toto statement and the retention anchor for an audit log is **rejected** in its pure form. A bare cryptographic hash lacks the semantic payload required for provenance (identity, policy, subject binding) and the temporal metadata required for retention governance (legal holds, expiration windows).

However, the goal of eliminating separate artifacts is achievable by collapsing these concerns into a single **Signed Composite Seal**. This seal embeds the in-toto statement structure, references the Merkle root for a bounded audit segment, and carries retention policy metadata, all bound together by a single signature. This approach preserves the efficiency of hash-based verification while satisfying the semantic requirements of supply chain integrity and legal retention.

## Findings

### 1. Semantic Insufficiency of Bare Hashes
A Merkle root is a commitment to a set of leaves. It proves inclusion and integrity but does not convey:
*   **Identity:** Who signed or produced the artifact?
*   **Provenance:** What step in the build/execution pipeline generated it?
*   **Policy:** Which compliance rules were applied?
*   **Subject Binding:** Explicitly naming the artifacts covered by the proof.

In the context of `hngh-automation`, relying solely on a root hash would fail to meet standard in-toto requirements for verifiable provenance. The statement must remain a structured JSON object (or equivalent) containing `_type`, `subject`, `predicate`, and signer information.

### 2. Retention Fragility of Global Roots
Using a single, ever-growing Merkle tree root as a retention anchor is operationally unsound. As new audit entries are appended, the root changes, invalidating previous anchors unless historical roots are explicitly versioned and stored separately. This defeats the purpose of a "single artifact" by necessitating a history of roots.

**Finding:** Retention anchoring must be **segmented**.
*   Audit logs should be partitioned into bounded segments (e.g., per execution batch, time window, or fixed entry count).
*   Each segment has its own root hash.
*   The retention anchor is not the global tree state, but the specific segment root plus its boundary metadata (`segment_start`, `segment_end`, `leaf_count`).

### 3. The Composite Seal Pattern
To satisfy the requirement of a single persisted artifact that serves both integrity and retention functions, the system should produce a **Composite Seal**. This is not a bare hash, but a signed container where:
1.  The **In-toto Statement** provides semantic integrity (who/what/why).
2.  The **Segment Merkle Root** provides cryptographic integrity for the audit log segment.
3.  The **Retention Metadata** provides legal/governance context (policy ID, expiration, hold status).
4.  A **Single Signature** binds all three components together.

This eliminates the need for separate "integrity file" and "retention manifest" artifacts. The seal is self-describing and verifiable in one pass.

## Recommendations

1.  **Do Not Use Bare Roots for In-toto:** Maintain the in-toto statement as a distinct semantic layer within the artifact. It must explicitly name subjects and predicates.
2.  **Implement Segment-Based Retention:** Partition audit logs into bounded segments. Each segment root is immutable once sealed. New entries go into new segments, preserving the integrity of historical anchors.
3.  **Adopt the Composite Seal Artifact:**
    *   Structure: A JSON object containing `statement` (in-toto), `audit_anchor` (segment root + boundaries), and `retention_policy` (ID, deadline, hold flag).
    *   Signing: Sign the canonicalized JSON of the entire seal.
    *   Verification: Verifiers check the signature first, then validate the in-toto statement semantics, then optionally verify the Merkle proof against the segment root if detailed audit entry inspection is required.
4.  **Kernel Integration (`hngh`):** In `[redacted path] ensure that any logging subsystem exposes a "seal" operation that accepts an in-toto payload and a log segment, producing this composite structure. Do not expose raw Merkle roots as the primary interface for compliance; expose the seal.

## Open Threads

1.  **Segment Boundary Strategy:** What is the optimal boundary for audit segments? Time-based (e.g., hourly) vs. Event-based (e.g., per deployment)? This impacts verification latency and storage overhead.
2.  **Legal Hold Propagation:** If a legal hold is applied to a segment, does it require re-signing the seal or a separate "hold marker" artifact? The current recommendation assumes the hold status is part of the signed seal metadata, which may be too rigid for dynamic holds. A sidecar mechanism might be needed for *dynamic* holds, while *static* retention policies are baked into the seal.
3.  **Cross-Segment Verification:** How does a verifier prove that Segment N was contiguous with Segment N-1? This requires linking segment roots (e.g., including the previous segment root in the new segment's metadata). This adds complexity to the "single artifact" model but is necessary for audit continuity.

## References

*   **Repository:** `[redacted path] (Kernel implementation context)
*   **Repository:** `hngh-automation` (Automation and compliance layer context)
*   **Standard:** in-toto Statement Specification (v1) – *Note: External standard, not verified in local repository files.*
*   **Prior Art:** `[[sources/SRC-2026-08-24-006]]` SLSA Supply Chain Levels for Software Artifacts.
