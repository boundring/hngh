# Why did the 2026-09-16 ui-audit axe scan report color-contrast on .gbar-lab labels inside three schedule gantt bars (.gtrack-row nth-child 20/76/77), why has the identity not re-fired since the 2026-09-27..10-04 dashboard rework, and what disposition (fix or park) closes it given the audit job itself went blind after the console moved off /?

Status: crystallized 2026-10-11 from research line `fail-20260916-ui-audit-axe-color-contrast`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-ui-audit-axe-color-contrast.md.

# Research Line: Final Structured Summary

**Line ID:** `Why did the 2026-09-16 ui-audit axe scan report color-contrast on .gbar-lab labels inside three schedule gantt bars (.gtrack-row nth-child 20/76/77), why has the identity not re-fired since the 2026-09-27..10-04 dashboard rework, and what disposition (fix or park) closes it given the audit job itself went blind after the console moved off /?`

**Lifecycle State:** Contracting — final record crystallized

**Model:** `unsloth:unsloth/Ornith-1.0-9B-GGUF`

---

## Findings

### Finding 1: The audit job went blind, not the finding

The axe scan identity has not re-fired since 2026-09-27..10-04 **not because the color-contrast violation was resolved**, but because the audit pipeline lost its execution target when the console routing moved off `/`. The absence of a new scan result is a pipeline failure, not evidence of remediation.

### Finding 2: The original violation was scoped to specific DOM positions

The 2026-09-16 scan reported color-contrast violations on `.gbar-lab` labels nested inside `.gtrack-row` elements at `:nth-child(20/76/77)`. This specificity suggests the violations were tied to a particular rendering context that may have been altered during the dashboard rework.

### Finding 3: `.gbar-lab` class fate is unresolved

Whether the `.gbar-lab` class was removed, renamed, or preserved during the 2026-09-27..10-04 dashboard rework is **not confirmed**. This is the critical variable that determines disposition:
- If `.gbar-lab` no longer exists → the original defect is moot → disposition "park"
- If `.gbar-lab` persists → the violation may still exist → disposition "fix"

### Finding 4: The audit job's dependency on console path is systemic

The axe scan's blindness after the console moved off `/` represents a systemic risk: any future console migration that does not verify audit pipeline targets will produce the same false-negative outcome.

---

## Recommendations

### Recommendation 1: Restore the audit job's target path (prerequisite)

**Action:** Locate the console routing configuration that moved off `/` and restore the axe scan's target path.

**Where to look (hngh kernel):**
- Console routing configuration in the dashboard service layer modified during 2026-09-27..10-04 rework
- CI/CD pipeline definitions that invoke the axe scan — check for hardcoded paths or environment variables referencing `/`

**Honesty note:** I cannot verify exact file paths without filesystem access to the repository. The team should search for `axe` references in CI configuration files and console path configuration in the dashboard service.

### Recommendation 2: Verify `.gbar-lab` class existence in post-rework codebase

**Action:** Search the hngh kernel repository for `.gbar-lab` class references across:
- HTML/template files that render gantt bars
- CSS files that style `.gbar-lab` or its descendants
- Component files that emit the `.gtrack-row` elements

**Honesty note:** I cannot verify the repository root path. The team should perform a string match for `.gbar-lab` across all file types in the kernel repository.

### Recommendation 3: Re-run the axe scan against current dashboard state

**Action:** Once the audit job's target path is restored, re-run the axe scan to determine:
- Whether color-contrast violations on `.gbar-lab` labels still exist
- Whether violations are on the same `.gtrack-row:nth-child(20/76/77)` elements or have shifted

**Disposition logic:**
| Condition | Disposition |
|-----------|-------------|
| Violations persist | **Fix** — with specific remediation |
| Violations resolved | **Park** — with evidence the defect no longer exists |
| Audit job cannot be restored | **Park** — with caveat that the finding cannot be re-verified |

### Recommendation 4: Document the audit job's dependency on console path

**Action:** Add a pre-migration checklist item to hngh-automation that verifies all audit/monitoring jobs have valid targets before console routing changes.

---

## Open Threads

1. **File path verification** — Cannot cite concrete file paths in the hngh kernel or hngh-automation repositories without filesystem access. Claims about where to look are directional, not definitive.

2. **`.gbar-lab` class fate** — Unknown whether the class was removed, renamed, or preserved during the dashboard rework. This is the single most important variable for disposition.

3. **Current violation status** — Unknown whether color-contrast violations on `.gbar-lab` labels persist in the current codebase, since the audit job has not re-fired.

4. **Console routing configuration** — Unknown which specific configuration moved the console off `/` and how to restore it.

---

## References

- **hngh kernel repository:** `[redacted path] — cited as the authoritative source for dashboard service layer, CI/CD pipeline definitions, and template/CSS/component files. File paths within this repository could not be verified without filesystem access.
- **hngh-automation repository:** Referenced as the location for pre-migration checklist items and audit pipeline configuration. File paths could not be verified.
- **Prior research beat 2026-10-11:** Contains the distillation of concrete recommendations and the honesty notes about file path verification limitations.
- **2026-09-16 ui-audit axe scan report:** Original finding on color-contrast violations on `.gbar-lab` labels inside `.gtrack-row:nth-child(20/76/77)`.
- **2026-09-27..10-04 dashboard rework:** Period during which the console moved off `/` and the audit job went blind.
- **Prior art — `[[sources/backlog-disposition-sweep-reduces-accepted-plans-by-half]]`:** Evidence-gated disposition methodology applicable to this line's fix/park decision framework.

---

**Record status:** Complete. This line is closed for further expansion. Any future re-opening should begin with Recommendation 1 (restore audit job target) before proceeding to disposition.
