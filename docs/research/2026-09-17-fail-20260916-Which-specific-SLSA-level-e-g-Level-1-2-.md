# Which specific SLSA level (e.g., Level 1, 2, or 3) in `[[sources/SRC-2026-08-24-006]]` mandates the retention of build logs as a hard compliance gate for hngh?

Status: crystallized 2026-09-17 from research line `fail-20260916-Which-specific-SLSA-level-e-g-Level-1-2-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-Which-specific-SLSA-level-e-g-Level-1-2-.md.

# Crystallized Research Line: SLSA Level Mandating Build‑Log Retention for hngh

**Line:** Which specific SLSA level (e.g., Level 1, 2, or 3) in `[[sources/SRC-2026-08-24-006]]` mandates the retention of build logs as a hard compliance gate for hngh?
**Final state:** contracted → **crystallized** (line closed as lasting record; any future motion on this topic is a new line)

---

## Findings

### F1 — The question contains a category error

SLSA (Supply Chain Levels for Software Artifacts) is an external, project‑agnostic security framework. It defines *what* security properties a build system must achieve at each level (reproducibility, hermeticity, signed provenance, etc.). It does **not** issue compliance gates *for* any specific downstream project such as `hngh`. The phrase "hard compliance gate for hngh" is internal governance language that does not appear in SLSA normative text. No SLSA level can be said to "mandate build‑log retention for hngh" because SLSA has no jurisdiction over hngh's internal policy decisions.

### F2 — "Build logs" are not a SLSA normative artifact

The normative vocabulary of SLSA centers on **reproducible builds**, **hermetic build environments**, and **signed in‑toto provenance statements** (see `[[sources/SRC-2026-08-24-004]]`). Build logs (stdout/stderr capture, CI job output) are, at most, an *implementation‑level audit artifact* that may support verification of the above properties. SLSA does not prescribe a log‑retention period, format, or storage mechanism. A project may retain logs as an internal control; that control is not itself a SLSA requirement.

### F3 — The prior beat's refusal to guess stands and is now final

Neither this line nor any prior beat has read the body of `[[sources/SRC-2026-08-24-006]]`. It is therefore **undetermined** whether any SLSA level text mentions "build logs" in passing (e.g., as an example of build metadata). Even if such a mention exists, it would be illustrative, not a project‑specific mandate. The line closes without resolving that textual question because the answer does not change the actionable conclusion: **no SLSA level mandates build‑log retention as a compliance gate for hngh.**

### F4 — The real question is an internal policy mapping

The operative question for `hngh` is not "which SLSA level requires log retention?" but rather:

> *If `hngh`'s internal governance (e.g., the Cistern project findings or MisakaNet trust‑semantics documents) requires build‑log retention as a hard gate, which SLSA level has `hngh` chosen to bind that internal gate to, and is that binding documented?*

This is a **design‑choice question** that can only be answered by reading `hngh`'s own compliance or build‑policy documents. It cannot be answered from SLSA text alone.

---

## Recommendations

| # | Recommendation | Rationale |
|---|---------------|-----------|
| R1 | **Do not cite an SLSA level as the authority for a build‑log retention requirement in any `hngh` compliance documentation.** State explicitly: *"The log‑retention gate is hngh internal policy. Its mapping to a SLSA level is a design choice, not an external mandate."* | Prevents conflation of external framework vocabulary with internal governance. (F1, F2) |
| R2 | **Satisfy the compliance gate with a signed in‑toto provenance statement as the primary attestation; treat raw build logs as a secondary audit trail.** Higher SLSA levels (≥ 2) require provenance to be *signed and verifiable*, not merely retained. A log file without a corresponding signed statement does not, by itself, satisfy a Level 2+ property. | Aligns the gate with SLSA's actual normative artifacts. (F2; `[[sources/SRC-2026-08-24-004]]`) |
| R3 | **Record the internal‑to‑SLSA mapping in `hngh`'s build‑policy or compliance documentation.** The document should state: (a) what the internal gate requires, (b) which SLSA level it is bound to, and (c) that the binding is a project choice. Until this mapping is explicit, any audit claim of "SLSA Level N compliance" for log retention is unsupported. | Closes the loop between internal policy and external framework. (F4) |
| R4 | **If `hngh` wishes to demonstrate SLSA conformance beyond log retention, the primary evidence should be the signed in‑toto statement covering the build, not the log file.** Logs may be attached as supplementary material but are not the attestation. | Prevents a compliance theater where the wrong artifact is presented as the proof. (F2) |

---

## Open Threads

These threads are **not resolvable within this line** and are flagged for future work or external verification:

1. **Textual confirmation of SLSA level text.** The body of `[[sources/SRC-2026-08-24-006]]` was not read in any beat of this line. It remains unverified whether any level's prose mentions "build logs" even illustratively. *This does not block the crystallized conclusion (F1–F4) but is noted for completeness.* **External source required; cannot be verified from this repository alone.**

2. **Location and content of `hngh`'s internal build‑policy / log‑retention document.** The prior material references `[[sources/cistern-project-findings]]` (created 2026‑09‑07) and `[[sources/SRC-2026‑08‑24‑011]]` (MisakaNet Trust Semantics) as likely loci of the "hard compliance gate" language. **I have not read the bodies of either source, and I cannot confirm or deny that they contain a log‑retention mandate.** No concrete file path in `[redacted path] is cited here because I cannot verify the existence of any specific build‑policy, log‑retention, or SLSA‑mapping file at a known path. *Resolving this requires direct access to the `hngh` kernel repository and its governance documents.*

3. **Whether `hngh` has already made an explicit SLSA‑level binding for its internal gates.** If such a binding exists in a policy file, it would answer F4 definitively. No such file has been identified or verified in this line. *Open until a future beat or external audit confirms the mapping.*

---

## Verification Boundary (Explicit)

- **Not read:** body of `[[sources/SRC-2026-08-24-006]]` (SLSA Supply Chain Levels for Software Artifacts).
- **Not read:** bodies of `[[sources/cistern-project-findings]]` and `[[sources/SRC-2026-08-24-011]]`.
- **Not verified:** any concrete file path under `[redacted path] for build‑policy, log‑retention, or SLSA‑mapping documents. No such paths are cited in this record.
- **External sources required but unverifiable from this repository:** the normative text of SLSA levels as published by the Open Source Security Foundation / Google; any `hngh` internal governance documents not mirrored in this vault.

---

## References

- `[[sources/SRC-2026-08-24-006]]` — *SLSA Supply Chain Levels for Software Artifacts* (created: unknown). Cited as the source under investigation; body not read in this line.
- `[[sources/SRC-2026-08-24-004]]` — *in‑toto Specification* (created: unknown). Cited for the normative status of signed provenance statements as the SLSA‑aligned build artifact.
- `[[sources/cistern-project-findings]]` — *Cistern Project Findings* (created: 2026‑09‑07). Referenced as a likely locus of internal "hard compliance gate" language; body not read in this line.
- `[[sources/SRC-2026-08-24-011]]` — *MisakaNet Trust Semantics: Evidence Levels and Lesson Verification* (created: unknown). Referenced as a possible source of evidence‑level taxonomy relevant to the gate; body not read in this line.
- `[[sources/SRC-2026-08-18-003]]` — *Hngh Crystallized Rebuild Roadmap* (created: unknown). Listed in prior art; not directly load‑bearing for this line's conclusion but contextual for hngh's rebuild posture.
