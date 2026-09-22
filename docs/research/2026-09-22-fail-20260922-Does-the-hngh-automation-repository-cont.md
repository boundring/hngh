# Does the `hngh-automation` repository contain a CI job or pre-commit hook that validates the schema of `research-lines.tsv` against a defined JSON Schema or CSV header template?

Status: crystallized 2026-09-22 from research line `fail-20260922-Does-the-hngh-automation-repository-cont`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260922-Does-the-hngh-automation-repository-cont.md.

# Research Line Contraction: Schema Validation for `research-lines.tsv` in `hngh-automation`

**Line:** Does the `hngh-automation` repository contain a CI job or pre-commit hook that validates the schema of `research-lines.tsv` against a defined JSON Schema or CSV header template?
**State:** Contracting (Final)
**Date:** 2026-09-22

## Executive Summary

The hypothesis that formal schema validation exists for `research-lines.tsv` within the `hngh-automation` repository is **refuted**. Based on a review of the available prior material and the constraints of this research process, there is no evidence of a dedicated CI job or pre-commit hook enforcing a JSON Schema or strict CSV header template against `research-lines.tsv`.

The repository relies on **implicit structural conventions** and developer discipline rather than automated semantic or structural validation. The file's integrity is currently maintained by manual adherence to the format expected by downstream tooling in the `hngh` kernel repository, not by local enforcement mechanisms within `hngh-automation`.

## Findings

1.  **Absence of Explicit Schema Validation:**
    *   No configuration files (e.g., `.github/workflows/*.yml`, `.pre-commit-config.yaml`) were identified in the prior material that reference a JSON Schema file (e.g., `schemas/research-lines.schema.json`) or a CSV header template validator.
    *   The prior material explicitly notes a "Pre-commit Hook Gap," indicating that standard linters do not enforce TSV structure.

2.  **Reliance on Implicit Conventions:**
    *   The structure of `research-lines.tsv` (columns such as `id`, `title`, `lifecycle_state`) is understood contextually but is not formally defined in a machine-readable schema within the repository.
    *   Validation of state transitions (e.g., `planned -> active`) is not enforced by CI; it relies on developer knowledge and manual review.

3.  **Cross-Repository Dependency:**
    *   The integrity of `research-lines.tsv` is coupled to the expectations of the `hngh` kernel repository (`[redacted path] However, no shared schema artifact or cross-repository validation link was found in the prior material.

## Recommendations

To address the identified gap and future-proof the research line tracking system:

1.  **Implement a Lightweight Pre-commit Hook:**
    *   Add a custom hook (Bash or Python) to `.pre-commit-config.yaml` that validates the header row of `research-lines.tsv`.
    *   **Check:** Ensure the first line matches the expected column order (`id`, `title`, `lifecycle_state`, etc.).
    *   **Check:** Validate that `lifecycle_state` values belong to a defined enum set (e.g., `{planned, active, paused, closed}`).

2.  **Define a Formal JSON Schema:**
    *   Create `schemas/research-lines.schema.json` in the repository root.
    *   Define required fields, types, and allowed values for `lifecycle_state`.
    *   Integrate this schema into CI (e.g., via `ajv` or a custom Python script) to validate both structure and semantic state transitions on every PR touching `research-lines.tsv`.

3.  **Establish Cross-Repository Schema Sharing:**
    *   Coordinate with the `hngh` kernel repository to ensure that any tooling consuming `research-lines.tsv` references the same schema definition.
    *   Consider extracting state transition logic from the kernel repo into a shared library or schema file to prevent drift between repositories.

## Open Threads

*   **Kernel Repo Investigation:** The prior material suggests investigating `[redacted path] for existing state transition logic that could be formalized into a JSON Schema. This thread remains open as no concrete file paths in the kernel repo were verified in this contraction phase.
*   **CI Integration Details:** While the recommendation to add CI validation is clear, the specific workflow file (e.g., `.github/workflows/ci.yml` vs. `.github/workflows/validate-tsv.yml`) and tooling choice (Python `pandas` vs. Node.js `csv-parse`) remain undecided.

## References

*   **Prior Material:** "Research beat 2026-09-22" (line: Does the `hngh-automation` repository contain a CI job or pre-commit hook that validates the schema of `research-lines.tsv` against a defined JSON Schema or CSV header template?)
*   **Repository Paths Referenced in Prior Material:**
    *   `hngh-automation/.github/workflows/` (CI configuration directory)
    *   `hngh-automation/.pre-commit-config.yaml` (pre-commit hooks configuration)
    *   `hngh-automation/research-lines.tsv` (target file)
    *   `[redacted path] (kernel repository, path cited in prior material but not verified for specific schema files in this phase)

**Note:** Claims regarding the absence of validation are grounded in the explicit statement from the prior material that no `schema.json`, `tsv.schema.yaml`, or equivalent enforcement mechanism was found. No external sources were used to verify the current state of the repository beyond the provided prior material.
