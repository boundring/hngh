# Can the hngh component map (SRC-2026-08-24-027) be regenerated mechanically from the tab registry at build time, turning a staling artifact into a continuously verified one?

Status: crystallized 2026-09-15 from research line `fail-20260915-Can-the-hngh-component-map-SRC-2026-08-2`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260915-Can-the-hngh-component-map-SRC-2026-08-2.md.

# Research Line: Mechanical Regeneration of the hngh Component Map (SRC-2026-08-24-027)

**Line ID:** SRC-2026-08-24-027
**Status:** Contracting → Crystallized
**Core Question:** Can the hngh component map be regenerated mechanically from the tab registry at build time, turning a staling artifact into a continuously verified one?

## Findings

### 1. The Provenance Note is a Testable Hypothesis, Not a Fact
The source document `[[sources/SRC-2026-08-24-027]]` contains the header: *"Auto-generated from meta/registry.json. Do not edit manually."*

This statement creates a **verification gap** rather than a generation problem. The line's value lies in resolving whether this claim is true, false, or partially true. Three distinct states exist:
1.  **Generator exists and is wired:** The map is already continuously verified; the line closes as "confirmed."
2.  **Generator exists but is unwired/drifted:** The map is stale relative to `meta/registry.json`; the fix is a build step + check mode.
3.  **No generator exists:** The header is aspirational or legacy; the line reopens as "write the generator," and the provenance note in SRC-2026-08-24-027 must be corrected to reflect reality.

### 2. Artifact Identity is Unconfirmed
The line references a "tab registry," while the provenance note cites `meta/registry.json`. **It has not been verified from this repository or `~/Projects/etc/hngh` that either file exists at these paths.** Until `ls meta/registry.json` and `ls ~/Projects/etc/hngh/meta/registry.json` are executed, any code written against a specific path is speculative. The "tab registry" may be a conceptual name for `meta/registry.json`, or they may be distinct files. This ambiguity must be resolved before implementation.

### 3. Determinism is a Hard Requirement for Verification
For the map to be "continuously verified," the generation process must be **deterministic**. If the generator emits non-deterministic output (e.g., unordered iteration, timestamps in content), a diff-based check will flake. The generator must:
-   Sort all iterations (components, dependencies, metadata).
-   Exclude wall-clock time from the output body.
-   Embed a **provenance header** containing:
    -   Generator version/hash.
    -   Hash of the input registry (`meta/registry.json`).
    This allows "staleness" to be decided by comparing hashes, not timestamps.

### 4. Existing Scaffolding Provides Vocabulary and Home
-   **SLSA Levels (SRC-2026-08-24-006):** A generated artifact with verifiable build provenance aligns with the "generated from source, verifiably" rung of SLSA. This line contributes to supply chain integrity for the hngh kernel.
-   **Overnight Harness (obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled):** An existing "built-verified-enabled" overnight harness is cited by pointer. Its actual behavior is unread from here, but it is the natural home for an idle-time full regenerate-and-verify pass.
-   **Crystallized Rebuild Roadmap (SRC-2026-08-18-003):** If regeneration becomes part of the hngh rebuild story, this line's outcome should be recorded there.

## Recommendations

### R1: Resolve Artifact Identity (Pre-Code)
Execute `ls meta/registry.json` and `ls ~/Projects/etc/hngh/meta/registry.json`. Read whichever exists. Confirm whether "tab registry" and `meta/registry.json` are the same file. **Do not write code until this is confirmed.**

### R2: Locate or Create the Generator
Search both repositories for the exact strings `"Do not edit manually"`, `"Auto-generated"`, and `SRC-2026-08-24-027`. Any code emitting that header *is* the generator.
-   **If found:** Proceed to R3/R4.
-   **If not found:** The line reopens as "write the generator." Correct the provenance note in SRC-2026-08-24-027 to remove the false claim until a generator is implemented.

### R3: Implement Deterministic Generator with Check Mode
The generator must support a **verify-only invocation**:
1.  Regenerate into a temporary buffer.
2.  Diff against the checked-in map file.
3.  Exit non-zero on drift.
4.  Embed provenance header (generator version + input hash).

### R4: Gate in Two Places
-   **Commit/CI Gate:** Run check mode whenever `meta/registry.json` changes. This converts the map from a staling artifact into a continuously verified one at the point of change.
-   **Idle-Host Gate:** Wire the check into the overnight harness (`obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled`) for periodic full regenerate-and-verify, catching out-of-band drift.

### R5: Frame with Existing Vault Scaffolding
Record the outcome in **SRC-2026-08-18-003** (Crystallized Rebuild Roadmap) if regeneration becomes part of the rebuild story. Use **SRC-2026-08-24-006** (SLSA levels) vocabulary for the provenance claim.

## Open Threads

1.  **Path Verification:** `meta/registry.json` existence and location are unconfirmed.
2.  **Generator Existence:** No code has been located that emits the provenance header. The "aspirational header" outcome is live.
3.  **Overnight Harness Behavior:** The harness's actual behavior is unread from here; wiring the check into it is a recommendation, not a description.
4.  **Tab Registry vs. meta/registry.json:** Whether these are the same file is unconfirmed.

## Definition of Done

1.  One canonical registry file identified and confirmed.
2.  A deterministic generator exists (or is written) that produces the map from that registry.
3.  The generator supports a check mode (regenerate-to-temp, diff, exit non-zero on drift).
4.  The provenance header in the map includes generator version and input hash.
5.  The check mode is wired into CI (on registry change) and/or the overnight harness.
6.  SRC-2026-08-24-027's provenance note is accurate: either "Auto-generated" is true, or it has been corrected to reflect reality.

## References

-   `[[sources/SRC-2026-08-24-027]]` — Hngh Component Map (provenance note source)
-   `[[sources/SRC-2026-08-24-006]]` — SLSA Supply Chain Levels for Software Artifacts
-   `[[sources/SRC-2026-08-18-003]]` — Hngh Crystallized Rebuild Roadmap
-   `[[sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled]]` — Observation: overnight harness pointer
-   `~/Projects/etc/hngh` — hngh kernel repository (path cited, existence of `meta/registry.json` unconfirmed)
