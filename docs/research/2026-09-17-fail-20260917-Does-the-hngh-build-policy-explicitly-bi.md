# Does the `hngh` build policy explicitly bind its internal log-retention gate to SLSA Level 2 or higher, and if so, is that binding documented in a compliance file?

Status: crystallized 2026-09-17 from research line `fail-20260917-Does-the-hngh-build-policy-explicitly-bi`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260917-Does-the-hngh-build-policy-explicitly-bi.md.

# Research Line: `hngh` Build Policy Log-Retention Gate and SLSA Level 2 Binding

**Line:** Does the `hngh` build policy explicitly bind its internal log-retention gate to SLSA Level 2 or higher, and if so, is that binding documented in a compliance file?
**State:** Contracting (Final Structured Summary)
**Date:** 2026-09-17

## Findings

The research line concludes that **no explicit binding exists** between the `hngh` build policy's log-retention gate and SLSA Level 2, nor is such a binding documented in a compliance file. The repository exhibits a *coverage claim* (the gate satisfies L2 requirements) rather than an *enforceable binding* (the gate is contingent on L2 status).

### 1. Policy Language: Permissive, Not Mandatory
- **`policy/build-policy.md`** uses permissive language ("SHOULD target SLSA Level 2 or where toolchain support permits"). This does not create a mandatory control trigger for the log-retention gate.
- There is no textual coupling in this file that makes the retention gate's activation contingent on the build's claimed SLSA level.

### 2. Log-Retention Policy: Coverage, Not Binding
- **`policy/log-retention.md`** asserts that the gate *satisfies* the audit-log requirements of SLSA Level 2.
- This is a one-directional coverage claim (Gate → Requirement). It does not state that the gate *fails* or *activates* only if the build claims L2, nor does it make the gate's enforcement contingent on L2 status.
- The gate fires unconditionally at build time; there is no conditional branch keyed to SLSA Level 2 in the policy text.

### 3. Compliance File: Explicit Disclaimer of Binding
- **`compliance/SLSA.md`** carries the header **"Status: Draft — mapping not yet ratified."**
- The file explicitly states: *"The mapping in this file is a claim of coverage, not a binding. Binding requires ratification per docs/build-policy.md §5."*
- The log-retention row is marked "Mapped," which records coverage, not an enforceable obligation.
- **No ratified binding document exists** in the repository.

### 4. Distinction: Coverage vs. Binding
- **Coverage:** The gate's output would be acceptable evidence *if* the build were already at L2.
- **Binding:** The gate's activation, scope, or failure semantics are contingent on the build claiming (or being assessed at) L2.
- The repository exhibits the former (coverage) and not the latter (binding).

## Recommendations

These recommendations are ordered by leverage to resolve the ambiguity in `hngh` / `hngh-automation`.

### R1 — Decide the Modality; Encode It in `policy/build-policy.md`
The current text ("SHOULD target SLSA Level 2...") leaves automation with no enforceable trigger. Pick one:
- **If L2 is mandatory for release builds:** Change to "MUST" and add explicit coupling: *"Any build that claims SLSA Level 2 or higher MUST pass the log-retention gate defined in policy/log-retention.md; failure of that gate is a release-blocking defect."*
- **If L2 remains aspirational:** Leave "SHOULD" but add a scope note: *"The retention gate is a flat internal control and is not conditioned on SLSA level."*
- **Goal:** Remove ambiguity so `hngh-automation` has a single boolean to evaluate.

### R2 — Add the Binding Clause (or Delete Coverage Sentence) in `policy/log-retention.md`
Today the file says the gate *satisfies* L2 audit-log requirements. This phrasing invites conflation of coverage with binding.
- **If R1 resolves to "MUST":** Append: *"This retention gate is a mandatory control for all builds claiming SLSA Level 2 or higher. A build that cannot commit logs to the retention store MUST fail before artifact publication, independent of any other provenance check."*
- **If R1 resolves to "Aspirational":** Replace the coverage sentence with: *"This retention gate is an internal audit control. It is not a SLSA-level precondition and its enforcement is not conditioned on the build's claimed supply-chain level."*

### R3 — Ratify or Withdraw `compliance/SLSA.md`
The file is in Draft status and self-describes as "a claim of coverage, not a binding." Two clean end-states:
- **Ratify:** Change Status to "Ratified," add ratification date and approver, and ensure the tabular mapping reflects enforceable obligations.
- **Withdraw:** If no binding is intended, remove the file or mark it as "Reference Only" to prevent misinterpretation as a compliance artifact.

## Open Threads

1. **Ratification Process:** `docs/build-policy.md §5` is referenced in `compliance/SLSA.md` as the mechanism for ratification. The content of §5 was not examined in this line; it may contain procedural requirements that, if met, would transform the coverage claim into a binding.
2. **Automation Implementation:** Whether `hngh-automation` currently implements any check keyed to SLSA level (e.g., a CI job that only runs the retention gate if a `slsa-level: 2` label is present) is not documented in the policy files. This would require inspection of the automation codebase, which is outside the scope of this policy-documentation line.
3. **External SLSA Verification:** The claim that the gate "satisfies" L2 audit-log requirements relies on an external interpretation of SLSA Level 2 criteria (specifically, the requirement for reproducible build logs and provenance). This line does not verify the technical adequacy of the gate against the official SLSA specification; it only examines the internal policy language.

## References

- `policy/build-policy.md`
- `policy/log-retention.md`
- `compliance/SLSA.md`
- `docs/build-policy.md` (referenced for ratification process, not directly examined)
