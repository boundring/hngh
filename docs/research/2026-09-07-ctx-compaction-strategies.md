# Which long-session compaction strategies (checkpointing state at turn boundaries) let a reborn session reorient in one bounded read without losing verified facts?

Status: crystallized 2026-09-07 from research line `ctx-compaction-strategies`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-ctx-compaction-strategies.md.

# Research Line Crystallization: Long-Session Compaction Strategies

**Line:** Which long-session compaction strategies (checkpointing state at turn boundaries) let a reborn session reorient in one bounded read without losing verified facts?
**State:** Contracting → Crystallized (Terminal Record)
**Date:** 2026-09-07
**Verification Status:** **Unverified against source code.** This record synthesizes design principles based on the line's internal history and prior art pointers. No specific file paths within `/home/bricker/Projects/etc/hngh` or the current repository were read or verified during this contraction phase. Claims regarding existing implementation are absent; all recommendations are forward-looking design constraints.

---

## 1. Executive Summary

The central problem is that narrative summaries of long sessions decay under repeated compaction, leading to "confidence laundering" (where unverified facts become indistinguishable from verified ones after paraphrasing). The solution is a **structured, append-only fact ledger** combined with a **hard-bounded reorientation document**.

Key insight: A reborn session cannot judge what to skip if the context is unbounded. Therefore, compaction must enforce a **write-time budget**, not a read-time discipline. Verification status (`verified` vs `unverified`) must be an atomic property of each fact record, preserved verbatim across compactions, with strict criteria for what constitutes "verified" (concrete evidence pointers).

## 2. Findings

### F1. Tool Calls Are Not Evidence
*   **Observation:** The line's own history demonstrated a failure mode where a beat recorded the *intent* of a tool call (`ls`) but not the *outcome*. After compaction, this indistinguishable from a verified step.
*   **Implication:** A checkpoint must record **outcomes**, not just actions. A "verified" status requires captured output (file contents, command exit codes, fetched data). Without this, the fact remains `unverified` regardless of how many times it is summarized.

### F2. Structured Ledgers Survive Compaction; Narratives Do Not
*   **Observation:** Free-text summaries are subject to paraphrasing errors in each compaction pass.
*   **Implication:** The state must be a ledger of structured records: `{claim, status, evidence_pointer, superseded_by}`. These entries are either carried verbatim or dropped. They are never re-worded, preventing semantic drift.

### F3. Write-Time Bounds Are Mandatory
*   **Observation:** If the reorientation document is allowed to grow dynamically, the system regresses to "read everything," defeating the purpose of compaction.
*   **Implication:** The bounded read (Tier 0) must have a fixed token/line budget enforced at **write time**. The reborn session has no context to judge relevance; it must trust the pre-filtered bound.

### F4. Turn-Boundary Checkpointing is Superior to Pressure-Based
*   **Observation:** Checkpoints triggered by context pressure are written by degraded, rushed sessions, leading to poor-quality summaries.
*   **Implication:** Checkpointing should occur at every turn boundary (or defined logical boundaries). This makes rebirth a pure read operation with no catch-up write required, ensuring the ledger is always fresh and authored by a healthy session state.

### F5. Freshness Markers Prevent Stale Trust
*   **Observation:** A reborn session trusting a stale ledger inherits false confidence if the underlying state has changed.
*   **Implication:** The bounded document must include a freshness marker (e.g., last turn ID, timestamp, or state hash). If the marker indicates staleness, the reborn session must treat all `verified` facts as suspect until re-checked against primary sources.

## 3. Recommendations for hngh / hngh-automation

1.  **Implement a Per-Turn Fact Ledger:**
    *   Do not summarize conversation prose.
    *   Extract atomic fact records at each turn boundary.
    *   Schema: `{ id, claim, status: [verified|unverified], evidence: <pointer>, timestamp }`.

2.  **Enforce Tiered State Architecture:**
    *   **Tier 0 (Bounded Reorientation):** A fixed-size document (e.g., max 5k tokens) containing only `verified` facts and current goals. This is the *only* thing a reborn session reads initially.
    *   **Tier 1 (Full Ledger):** The append-only history of all fact records, including `unverified` and `superseded` entries. Used for audit or deep dive if Tier 0 is insufficient.

3.  **Strict Verification Criteria:**
    *   A fact is `verified` only if it has a concrete evidence pointer (e.g., `file:line`, `command_output_hash`, `url_fetched`).
    *   No evidence = `unverified`.
    *   Compaction must not promote `unverified` to `verified` without new evidence.

4.  **Freshness Validation Protocol:**
    *   Tier 0 document must include a `last_verified_turn_id` or `state_hash`.
    *   On rebirth, if the current session state does not match the marker, flag all facts for re-verification before acting on them.

5.  **Atomic Supersession:**
    *   When a fact is invalidated, do not delete it. Mark it `superseded_by: <new_fact_id>`. This preserves the audit trail and prevents "zombie" facts from resurfacing if the superseding fact is later removed.

## 4. Open Threads

*   **Implementation in hngh:** How does the hngh kernel currently handle state persistence? (Unverified). Does it support append-only ledgers or only snapshot-based saves?
*   **Evidence Pointer Resolution:** How should evidence pointers be resolved? If a file path is cited, does the reborn session need to re-read the file to confirm the fact is still true, or is the pointer sufficient for "verified" status in the short term?
*   **Cost of Turn-Boundary Checkpointing:** What is the computational overhead of extracting structured facts at every turn? Is it negligible compared to the cost of a failed rebirth?

## 5. References

*Note: The following are prior art pointers from the llm-wiki vault provided in the prompt context. Their contents were not read during this contraction.*

*   `[[entities/bounded-delegation]]` – Bounded Delegation
*   `[[sources/SRC-2026-08-18-004]]` – Bounded Delegation Tooling
*   `[[concepts/session-salvage]]` – Session Salvage (created: 2026-08-24)
*   `[[sources/hngh-storeless-cli-state-loss]]` – Hngh storeless CLI state loss in multi-process flows
*   `/home/bricker/Projects/etc/hngh` – Kernel repository root (contents unverified)
*   `research-lines.tsv` – Line-state file (referenced in prompt header)

---
**End of Crystallization Record**
