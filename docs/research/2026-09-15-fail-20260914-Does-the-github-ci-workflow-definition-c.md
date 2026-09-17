# Does the github-ci workflow definition contain an embedded copy of the patrol verdict rule, and does it diff against the kernel's canonical rules file?

Status: crystallized 2026-09-15 from research line `fail-20260914-Does-the-github-ci-workflow-definition-c`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260914-Does-the-github-ci-workflow-definition-c.md.

# Contracted Research Line: GitHub CI Workflow — Embedded Patrol Verdict Rule & Canonical Diff

**Line:** Does the github-ci workflow definition contain an embedded copy of the patrol verdict rule, and does it diff against the kernel's canonical rules file?
**State:** contracting → **closed (final record)**
**Repository under investigation:** `hngh/hngh-automation` (GitHub Actions workflows)
**Canonical source:** `~/Projects/etc/hngh` (kernel repository)

---

## Findings

### 1. The verdict rule is embedded in the CI surface — confirmed by prior drift evidence

The vault note **`verdict-rule-drift-two-surfaces`** ("Shared verdict rule drifted across two surfaces") records a prior finding that the patrol verdict rule exists in at least two independent locations and has diverged between them. This directly answers the first half of the line: **yes, an embedded copy of the verdict rule is present in the CI/workflow surface** (or a script it invokes), rather than being sourced from the kernel's canonical file at build or run time.

The note title itself — "drift" — implies the two surfaces are not kept in lockstep by any mechanical synchronization, which is the operational signature of an embedded copy that was once pasted and has since been edited independently.

### 2. No evidence of a diff-against-canonical check

No artifact in the prior material or vault notes records a CI step that diffs the embedded rule against the kernel's canonical rules file. The absence of such a check is consistent with the drift being discovered (per the note) rather than prevented: if a mechanical diff gate existed, the two surfaces would not have drifted undetected. I cannot verify the full contents of any workflow YAML in `hngh/hngh-automation` from this position; I am inferring the absence of a diff step from the *presence* of drift and the *absence* of any note recording a reconciliation gate.

### 3. The two surfaces (as far as prior material identifies)

| Surface | Location (inferred) | Role |
|---|---|---|
| Kernel canonical rules file | Somewhere under `~/Projects/etc/hngh` | Source of truth for the patrol verdict rule |
| CI-embedded copy | A workflow definition or invoked script in `hngh/hngh-automation` (e.g. `.github/workflows/*.yml` or a shell/Python helper it calls) | Operational copy used by the CI pipeline |

I am **not confident** in the exact filename of the canonical rules file inside the kernel tree, nor in the exact workflow YAML path inside `hngh/hngh-automation`. The vault note does not record them, and I do not have filesystem access to enumerate them here. Citing a specific path without verification would violate the grounding constraint.

### 4. Drift is the operative risk, not mere duplication

The prior art note frames this as a *drift* problem, not simply a duplication problem. The embedded copy has already diverged from canonical. This means:

- The CI pipeline may be enforcing a **stale or mutated** version of the verdict rule.
- Kernel-side changes to the rule are **not mechanically propagated** to the CI surface.
- There is no recorded reconciliation mechanism (diff, sync script, or generated artifact) tying the two together.

This aligns with the broader vault context: `voice-rules-as-binding-constraint-not-aesthetic-preference` treats rules as binding constraints, so a drifted embedded copy is not a cosmetic issue — it changes what the pipeline actually enforces.

---

## Recommendations

1. **Locate and inventory both surfaces.** On an idle host with access to both repositories, identify:
   - The exact canonical rules file path under `~/Projects/etc/hngh`.
   - The exact workflow YAML (or invoked script) in `hngh/hngh-automation` that contains the embedded verdict rule.
   Record both paths in the vault so future beats can cite them concretely.

2. **Add a mechanical diff gate to CI.** Introduce a step in the relevant workflow that fetches or references the canonical rules file and diffs it against the embedded copy, failing the pipeline on divergence. This converts the drift from a silent risk into a loud, actionable signal. The pattern is consistent with the vault's `long-gates-run-async-against-interjections` and `async-proof-pattern-for-long-drop-ins`: if the diff requires network access to the kernel repo, run it as an async gate rather than blocking the main pipeline synchronously.

3. **Prefer sourcing over embedding.** If feasible, restructure the CI workflow to *read* the verdict rule from the canonical file at runtime (via a checkout of the kernel repo, a published artifact, or a generated config) rather than carrying an inline copy. This eliminates the drift surface entirely.

4. **If embedding must remain, add a generation step.** Generate the embedded copy from the canonical source as part of a release or sync process, so that any divergence is caught at generation time rather than at patrol time.

5. **Record the reconciliation in the vault.** Once the diff gate or sourcing change lands, update `verdict-rule-drift-two-surfaces` to reflect the remediation and close the drift thread.

---

## Open Threads

- **Exact file paths unverified.** The canonical rules file path in the kernel tree and the specific workflow/script path in `hngh/hngh-automation` are not recorded in any prior material I can cite. A short beat on an idle host with filesystem access should close this gap and update the vault note with concrete paths.
- **Scope of "patrol verdict rule."** The prior material does not define the full extent of the rule (single predicate vs. multi-clause policy). If the rule is large, a simple diff may be insufficient; a structured comparison (e.g., parse both into a canonical form and compare) may be warranted.
- **Other embedded copies.** The vault note says "two surfaces," but does not exclude the possibility of additional copies (e.g., in test fixtures, documentation examples, or other automation repos). A grep across `hngh/hngh-automation` for the rule's distinctive tokens would confirm whether two is the complete count.
- **External sources.** I have no access to GitHub's rendered workflow UI, CI run logs, or any external documentation for these repositories. All findings above are grounded in the vault notes and prior material provided in this line. Any claim about specific YAML structure, step ordering, or script logic would require direct inspection of the files and is **not asserted here**.

---

## References

- `[[entities/hngh]]` — Hngh Agent Kernel (vault entity; context for kernel repo role)
- `[[sources/verdict-rule-drift-two-surfaces]]` — "Shared verdict rule drifted across two surfaces" (primary evidence for embedded copy and drift)
- `[[sources/voice-rules-as-binding-constraint-not-aesthetic-preference]]` — Rules as binding constraints (frames drift as an enforcement-integrity issue)
- `[[sources/long-gates-run-async-against-interjections]]` — Async gate pattern (informs recommendation 2)
- `[[sources/async-proof-pattern-for-long-drop-ins]]` — Background job proof pattern (informs recommendation 2)
- `[[sources/debug-repro-sandboxes-only]]` — Sandbox constraint (relevant if a repro of the drift is needed)
- `~/Projects/etc/hngh` — Kernel repository root (canonical source location; exact rules file path not yet recorded in vault)
- `hngh/hngh-automation` — Automation repository (CI workflow surface; exact workflow/script path not yet recorded in vault)
