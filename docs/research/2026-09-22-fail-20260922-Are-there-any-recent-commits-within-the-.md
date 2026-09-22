# Are there any recent commits (within the last 30 days) in `hngh-automation` that modify `research-lines.tsv` without corresponding changes to CI or pre-commit configurations, indicating ongoing reliance on manual discipline?

Status: crystallized 2026-09-22 from research line `fail-20260922-Are-there-any-recent-commits-within-the-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260922-Are-there-any-recent-commits-within-the-.md.

# Research Line Contraction: `hngh-automation` State Integrity & Manual Discipline

**Line:** Are there any recent commits (within the last 30 days) in `hngh-automation` that modify `research-lines.tsv` without corresponding changes to CI or pre-commit configurations, indicating ongoing reliance on manual discipline?
**State:** contracting -> **contracted**
**Date:** 2026-09-22

## Executive Summary

This line is contracted due to a fundamental epistemic barrier: the specific repository `hngh-automation` and its commit history are not accessible within the current execution environment. The prior material correctly identified the *risk* of manual discipline but failed to ground its claims in verifiable data from the target repository.

The core finding is that **the hypothesis cannot be confirmed or refuted** without direct access to `hngh-automation`'s git history and CI configuration files. However, based on the available prior art (specifically `LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu`) and standard automation practices, we can crystallize the *structural vulnerability* and provide prescriptive recommendations for enforcement. The "manual discipline" risk is high if no automated schema validation or cross-reference integrity checks exist in `hngh-automation`.

## Findings

1.  **Inability to Verify Commit History:**
    *   No direct access to `hngh-automation` repository was available to inspect commits from the last 30 days (2026-08-22 to 2026-09-22).
    *   Consequently, it is impossible to determine if `research-lines.tsv` has been modified without corresponding CI/pre-commit changes.

2.  **Schema Vulnerability Identified in Prior Art:**
    *   The prior lesson `LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu` indicates a previous failure to define or enforce the schema of `research-lines.tsv`. This suggests that the TSV format is informal or undocumented, increasing the likelihood of manual errors.
    *   The lesson `LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca` highlights uncertainty about exact file paths, implying that automated tooling may not have reliable pointers to validate state files.

3.  **Architectural Decoupling Risk:**
    *   The `hngh` kernel repository (`[redacted path] is referenced as the core logic provider. If `hngh-automation` wraps this kernel, any drift in `research-lines.tsv` (state definition) without corresponding validation in CI (state enforcement) creates a silent failure mode where research lines are tracked but not validated.

## Recommendations

To mitigate the risk of ongoing reliance on manual discipline, the following prescriptive actions are recommended for `hngh-automation`:

### 1. Implement Schema Validation via Pre-commit Hooks
*   **Action:** Create a script (e.g., `scripts/validate_research_lines.py`) in `hngh-automation` that:
    1.  Parses `research-lines.tsv`.
    2.  Asserts consistent column count per row.
    3.  Validates `lifecycle_state` against an allowed enum (e.g., `planned`, `active`, `expanding`, `contracted`, `closed`).
    4.  Verifies that `line` descriptions are non-empty and unique.
*   **Integration:** Add this script to `.pre-commit-config.yaml`. If pre-commit is not yet used, introduce it as a lightweight gate to make invalid states impossible to commit.

### 2. Enforce Cross-Reference Integrity in CI
*   **Action:** Introduce a CI job that runs on every PR modifying `research-lines.tsv`. The job should:
    1.  Parse the diff of `research-lines.tsv`.
    2.  Identify new or modified `line` entries.
    3.  Check if corresponding artifacts exist in the `llm-wiki vault` (e.g., a file named after the line ID or a pointer in a registry).
    4.  Fail the CI if a new line is added without a corresponding vault entry, or if an existing line is modified without updating its associated metadata.
*   **Rationale:** This ensures referential integrity, preventing orphaned research lines or broken links in the continuous research process.

### 3. Centralize State Validation Logic in `hngh` Kernel
*   **Action:** If `hngh-automation` wraps the `hngh` kernel, ensure that state validation logic is centralized in the kernel and exposed via a CLI or library interface. This allows both CI and pre-commit hooks to use the same validation logic, reducing duplication and drift.

## Open Threads

1.  **Verification of `hngh-automation` Repository Structure:**
    *   Confirm whether `hngh-automation` exists as a separate repository or is a directory within `hngh`.
    *   Verify if `.pre-commit-config.yaml` and CI configuration files (e.g., `.github/workflows/ci.yml`) exist in `hngh-automation`.

2.  **Schema Definition for `research-lines.tsv`:**
    *   Define and document the exact schema for `research-lines.tsv`, including column names, allowed values for `lifecycle_state`, and any required fields.
    *   Update the prior lesson `LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu` with the defined schema.

3.  **Integration of Validation Logic:**
    *   Implement the recommended pre-commit hook and CI job in `hngh-automation`.
    *   Test the validation logic against historical commits to ensure it would have caught previous errors (if any).

## References

*   `[[sources/LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu]]` - Research Lesson: Does the research-lines.tsv schema include...
*   `[[sources/LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca]]` - Research Lesson: What are the exact file paths for the ca...
*   `[[sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled]]` - Observation: hngh-automation overnight harness built, verified, enabled.
*   `[redacted path] - hngh kernel repository (assumed path based on prior material).
