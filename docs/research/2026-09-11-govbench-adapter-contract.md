# What adapter contract lets different change-governance systems run the same governance benchmark unmodified?

Status: crystallized 2026-09-11 from research line `govbench-adapter-contract`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-govbench-adapter-contract.md.

## Final Structured Summary: Adapter Contract for Change-Governance Systems

### Findings

The research line identified the need for an adapter contract that allows different change-governance systems to run the same governance benchmark unmodified. The core insight is that the benchmark must operate on a **Canonical Change Event (CCE)** schema, which ensures that the benchmark remains agnostic to the source system. The adapter contract serves as a bidirectional translation layer that maps system-specific change requests to CCEs and vice versa.

### Recommendations

1. **Define the Canonical Change Event (CCE) Schema:**
   - The benchmark must be agnostic to the source system, requiring all inputs to be normalized into a CCE.
   - A CCE should minimally contain:
     - `change_id`: Unique identifier for the proposed change.
     - `actor`: The entity requesting the change (mapped to a neutral ID).
     - `scope`: A structured representation of what is being changed (e.g., file paths, API endpoints, config keys).
     - `intent`: A declarative description of the change's purpose (aligned with `delegated-contract-verification`).
     - `context`: Metadata required for policy evaluation (e.g., time, environment, prior state hash).
   - **Action:** In `hngh/hngh-automation`, create a `cce.schema.json` or equivalent Rust/Python data structure. All governance adapters must serialize their native change requests into this schema before passing them to the benchmark.

2. **Implement the Adapter as a "Verification Delegate," Not a "Policy Engine":**
   - The benchmark contains no policies; it only verifies that the adapter correctly delegates verification.
   - The contract is defined as:
     - **Input:** A CCE and a set of verification rules (defined by the benchmark, not the system).
     - **Process:** The adapter forwards the CCE to the underlying governance system’s native verification endpoint.
     - **Output:** A normalized `VerificationResult` struct: `{ status: Pass | Fail | Error, evidence: String, latency_ms: u64 }`.
   - **Action:** In `hngh/hngh-automation`, define an `AdapterTrait` (or equivalent) with a single method:
     ```rust
     trait GovernanceAdapter {
         fn verify(&self, cce: &CanonicalChangeEvent, rules: &BenchmarkRules) -> VerificationResult;
     }
     ```
   - The benchmark engine calls this trait. It does not know *how* the adapter verifies, ensuring the benchmark logic is never modified when adding a new governance system.

3. **Separate "Enforcement" from "Verification" in the Automation Harness:**
   - `hngh/hngh-automation` is an automation harness, not a governance system.
   - Its role is to:
     - Capture changes (e.g., via git hooks or API interceptors).
     - Normalize them into CCEs.
     - Delegate verification to the appropriate governance system via the adapter.
   - **Action:** Ensure that `hngh/hngh-automation` captures and normalizes changes, and delegates verification to the adapter.

### Open Threads

1. **Integration with Existing Governance Systems:**
   - How to integrate existing governance systems into the new adapter contract framework.
   - **Action:** Develop specific adapters for each existing governance system to ensure seamless integration.

2. **Benchmark Rules and Verification Rules:**
   - How to define and manage

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
