# Reconcile the pins-file identity (automation/config/hngh-packages.tsv collected-repositories registry vs automation/config/hngh-pins.tsv pins; comparator automation/jobs/pins-drift.py landed 2026-09-27), add the exit 0/1/2 drift convention (0 clean, 1 drift, 2 input error), and land a first drift report, feeding the governed package operations backlog row.

Status: crystallized 2026-10-05 from research line `os-package-drift-comparator`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-os-package-drift-comparator.md.

# Research Line: Pins-File Identity Reconciliation — Final Contracting Summary

**Line state:** `research-lines.tsv` — `contracting`  
**Line ID:** `Reconcile the pins-file identity (automation/config/hngh-packages.tsv collected-repositories registry vs automation/config/hngh-pins.tsv pins; comparator automation/jobs/pins-drift.py landed 2026-09-27), add the exit 0/1/2 drift convention (0 clean, 1 drift, 2 input error), and land a first drift report, feeding the governed package operations backlog row.`  
**Lifecycle:** Final distillation artifact. No further expansion.  
**Model used:** `unsloth:unsloth/Ornith-1.0-9B-GGUF`  
**Wall clock:** 30.0s  

---

## 1. Findings

### F1. Asymmetric identity between two TSVs

The repository maintains two distinct configuration artifacts with asymmetric roles:

| File | Role | Identity claim |
|------|------|----------------|
| `automation/config/hngh-packages.tsv` | Registry | Breadth — what is tracked |
| `automation/config/hngh-pins.tsv` | Pins | Commitment — what is pinned |

These files encode a registry-vs-pins relationship that, when reconciled, produces drift signals. The comparator `automation/jobs/pins-drift.py` (landed 2026-09-27) is the mechanism for detecting disagreement between them.

**Confidence:** High — these file paths are cited in the prior material as existing within the hngh repository at `[redacted path]

### F2. Exit convention is defined but implementation status is unverified

The exit code convention (0 clean, 1 drift, 2 input error) is specified as part of the line's deliverable. This convention creates a hard contract: the comparator must distinguish three states of operation, and conflating any two is a design failure.

**Confidence:** High — the convention is stated in the line definition. Whether `automation/jobs/pins-drift.py` implements it is unverified from this context.

### F3. Drift report is a deliverable, not an optional artifact

The line terminates in a drift report that feeds the governed package operations backlog row. This means the report is not merely diagnostic — it is operational input. Its format must support programmatic consumption.

**Confidence:** High — stated in the line definition. Whether a drift report has been produced is unverified.

### F4. Three drift cases are structurally necessary

Given the asymmetric roles of registry and pins, collapsing disagreement into a single "drift" signal loses actionable information. The three cases (registry-only, pins-only, field-level mismatch) are structurally required by the identity claims of the two TSVs.

**Confidence:** High — this follows from F1. Whether the comparator already distinguishes them is unverified.

### F5. Policy precedes resolution

Drift detection is a technical problem; drift resolution is a policy problem. The line's deliverable (first drift report feeding the backlog) cannot be meaningfully acted on without explicit policy on what drift cases are acceptable and how to resolve them.

**Confidence:** High — this follows from F3 and F4. Whether such policy exists in the repository is unverified.

### F6. Prior recommendations were truncated

Recommendation R4 (registry-pins policy must be explicit) was cut off at 4000 bytes in the prior material. The remaining recommendations (R1–R3) are complete.

**Confidence:** High — the truncation is observable in the prior material.

---

## 2. Recommendations

### R1. Schema validation is the gatekeeper for exit code 2 — build it before the comparator runs

The exit convention (0/1/2) makes schema validation the implicit contract for `automation/jobs/pins-drift.py`. If the comparator cannot distinguish "input error" from "drift," it cannot honor exit code 2. This means:

- **Before any comparison logic**, the comparator must validate both TSVs against a schema (column names, types, required fields, value constraints).
- **Validation failures must produce exit 2 with a diagnostic message** identifying which file, row, and field failed.
- **No drift signal (exit 1) should ever be emitted from malformed input** — that would conflate operational failure with policy signal.

*Confidence:* This recommendation follows directly from the stated exit convention and the diff/grep idiom (F2). I assert nothing about whether `automation/jobs/pins-drift.py` currently implements this.

### R2. The comparator must distinguish three drift cases, not one

The two TSVs encode asymmetric identity claims (F1): registry (breadth) vs. pins (commitment). Collapsing all disagreement into a single "drift" signal loses actionable information. The comparator should emit at minimum:

| Case | Meaning | Actionability |
|------|---------|---------------|
| **Registry-only** | Package tracked but unpinned | Pin it, or remove from registry |
| **Pins-only** | Pin references untracked source | Verify source, add to registry, or remove pin |
| **Field-level mismatch** | Same package, disagreeing field | Resolve which field is authoritative |

*Confidence:* The three cases are structurally necessary given the asymmetric roles of the two TSVs (F1). Whether `automation/jobs/pins-drift.py` already distinguishes them is unverified from this context.

### R3. The first drift report must be a triage artifact, not just a signal

The line terminates in a drift report that feeds the governed package operations backlog row (F3). The report's format determines whether the backlog can be acted on. Minimum requirements:

- **Per-drift-entry structure:** package name, drift case (registry-only / pins-only / field-mismatch), affected fields, severity (critical / warning / informational), and suggested resolution.
- **Summary header:** total drift count, breakdown by case, total registry entries, total pins entries, total orphan entries.
- **Machine-readable format:** TSV or JSON alongside human-readable summary, so the comparator can be re-run and the backlog updated programmatically.

*Confidence:* This follows from the line's stated deliverable (first drift report feeding the backlog). I assert nothing about the current format of any drift report.

### R4. The registry-pins policy must be explicit before drift resolution can begin

Drift detection is easy; drift resolution requires a policy. Before the first drift report can be meaningfully acted on, hngh needs to answer:

- **Is registry-only drift acceptable?** (i.e., is it OK to track packages without pins?)
- **Is pins-only drift acceptable?** (i.e., can pins reference sources not in the registry?)
- **Which field is authoritative when registry and pins disagree on the same field?**
- **What is the severity classification for each drift case?**

*Confidence:* This follows from F5. Whether such policy exists in the repository is unverified. **This recommendation was truncated in prior material and requires completion.**

---

## 3. Open Threads

| Thread | Status | Notes |
|--------|--------|-------|
| **R4 completion** | Open | R4 was truncated at 4000 bytes; registry-pins policy recommendations need to be finished |
| **Schema validation implementation** | Unverified | Whether `automation/jobs/pins-drift.py` implements schema validation before comparison is unverified |
| **Three-case drift distinction** | Unverified | Whether the comparator already distinguishes registry-only / pins-only / field-mismatch is unverified |
| **First drift report produced** | Unverified | Whether a drift report has been generated and landed is unverified |
| **Registry-pins policy in repository** | Unverified | Whether hngh contains explicit policy on registry-vs-pins drift resolution is unverified |
| **Backlog integration** | Unverified | Whether the governed package operations backlog row exists and accepts drift report input is unverified |

---

## 4. References

### Repository paths (confident — cited in prior material)

- `[redacted path] — collected-repositories registry
- `[redacted path] — pins
- `[redacted path] — comparator (landed 2026-09-27)
- `[redacted path] — line state registry
- `[redacted path] — governed package operations backlog row (inferred from line definition)

### Prior art (llm-wiki vault; read-only pointers)

- `[[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]]` — Research Lesson: Does the obs 2026-08-25 hngh automation
- `[[sources/LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca]]` — Research Lesson: What are the exact file paths for the ca
- `[[sources/SRC-2026-08-24-022]]` — Hngh Project Backlog
- `[[concepts/clean-architecture]]` — Clean Architecture for Agent Systems
- `[[concepts/clean-architecture-for-machine-intelligences]]` — Clean Architecture for Machine Intelligences
- `[[sources/SRC-2026-08-18-007]]` — Git Back Dots - Git-backed System Config & Dotfile Manager

### External sources

**None asserted.** All claims are grounded in the hngh repository and the prior material on this line. No external sources were invoked.

---

## 5. Line Closure

This line is now in `contracting` state. The final structured summary above is the lasting record. No further expansion is planned. Work continues on idle hosts; this note is the distillation artifact.

**Next action (if any):** Complete R4 (registry-pins policy) and verify whether the comparator and drift report already exist in the repository.
