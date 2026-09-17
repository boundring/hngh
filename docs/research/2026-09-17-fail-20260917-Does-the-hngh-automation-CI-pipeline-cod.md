# Does the `hngh-automation` CI pipeline code contain any conditional logic that keys the execution or failure of the log-retention gate to a `slsa-level` metadata field?

Status: crystallized 2026-09-17 from research line `fail-20260917-Does-the-hngh-automation-CI-pipeline-cod`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260917-Does-the-hngh-automation-CI-pipeline-cod.md.

# Final structured summary — `hngh-automation` log-retention gate × `slsa-level` conditional

**Line state:** contracted  
**Question:** Does the `hngh-automation` CI pipeline code contain any conditional logic that keys the execution or failure of the log-retention gate to a `slsa-level` metadata field?

## Answer

No verified instance can be reported from the available record.

The supplied material defines the evidence standard for a positive answer, but it does not provide a verified `file:line` in the `hngh-automation` CI pipeline showing that a log-retention gate is conditioned on a field named or aliased to `slsa-level`. Therefore, this line cannot support a positive claim.

It also cannot yet certify a clean negative-at-HEAD result, because the required audit trail — an exhaustive enumeration of every log-retention component and every conditional guarding it — is not present in the supplied material. Absence of a search hit in the available text is not absence of evidence in the repository.

The durable finding is: **no confirmed coupling; negative-at-HEAD remains unproven until the static trigger-topology audit is executed against the actual `hngh-automation` repository and the cross-repository dataflow paths are closed.**

---

## Findings

### F1 — A positive answer requires a three-part causal chain

A valid positive finding must establish all of the following:

1. **A log-retention gate exists.**  
   The component must control whether logs or artifacts are retained, uploaded, pruned, or otherwise preserved in a binary/conditional way. It is not enough that the pipeline computes a retention duration.

2. **A `slsa-level`-like metadata field exists.**  
   The field may be named exactly `slsa-level` or use a documented alias, but it must carry SLSA-level-like metadata.

3. **Conditional logic reads that field and changes whether the gate executes or fails.**  
   The predicate may appear in GitHub Actions `if:`, `when:`, `continue-on-error`, shell tests, Makefile guards, reusable-workflow inputs, matrix dimensions, environment variables, job outputs, or third-party action configuration.

All three parts must be linked at a concrete `file:line`. A duration knob does not satisfy this standard.

### F2 — No verified positive evidence is available in the supplied record

The prior material contains the contract and recommended audit moves, but it does not provide a verified repository file showing:

- a retention gate guarded by an `slsa-level` predicate;
- a job output such as `outputs.slsa-level` consumed by a retention job’s `if:`;
- an environment variable such as `$SLSA_LEVEL` or `$slsa_level` read by a retention step;
- a matrix dimension keyed to SLSA level controlling retention execution;
- a reusable-workflow parameter passing SLSA level into a retention gate;
- a third-party action emitting or consuming SLSA level in a way that controls retention.

Therefore, no positive claim is supportable from the available material.

### F3 — A negative-at-HEAD conclusion is not yet certified

A clean negative requires more than the absence of an obvious `slsa-level` string near a retention job. It requires an audit trail showing:

- every retention-related component in the pipeline was identified;
- every conditional guarding that component was enumerated;
- none of those conditionals reads `slsa-level` or a documented alias;
- cosmetic mentions were examined and ruled out, such as log strings, comments, documentation, job names, or labels.

Without that audit trail, the negative remains unfalsifiable in the supplied record.

### F4 — Duration knobs must be excluded from the gate definition

If the pipeline contains something like:

```yaml
retention-days: ${{ fromJSON(needs.meta.outputs.env).slsa-level * 7 }}
```

that would be a **duration knob**, not a log-retention gate. It changes how long logs persist, not whether they are retained at all. Such a reference would be relevant context, but it would not satisfy the positive-answer standard unless it also controlled execution or failure of a retention component.

### F5 — Cross-repository coupling remains open

The kernel repository may emit SLSA-level-like metadata that the automation pipeline consumes. A possible chain would be:

```text
kernel build/provenance emission
→ automation ingestion
→ retention-gate predicate
```

The supplied material does not verify such a chain. It is therefore an open thread, not a finding.

### F6 — External SLSA definitions are not required for the code-level answer

The question is about conditional logic in CI pipeline code, not about the normative meaning of SLSA levels. I cannot verify external SLSA documentation from this transition, and no such external source is needed to decide whether a repository contains the relevant conditional logic.

---

## Recommendations

### R1 — Execute the static trigger-topology audit before closing the line as negative

Run the audit from the `hngh-automation` repository root against HEAD and any branch or PR that could be considered live pipeline state.

The decisive test is:

```bash
rg -n -i 'slsa' --type yaml --type yml
rg -ni 'retention|retain|prune|keep.*log|upload.*artifact.*log|log.*upload|actions/upload-artifact'
```

For every retention-related hit, enumerate every conditional guarding it:

- `if:`
- `when:`
- `needs:`
- `continue-on-error`
- shell `test`, `[ ]`, or `[[ ]]`
- Makefile guards
- reusable-workflow inputs
- matrix dimensions
- environment-variable reads

Then check whether any predicate reads `slsa-level` or a documented alias.

**Closure rule:**  
If no conditional on a retention component reads `slsa-level`, record **negative-at-HEAD**. The record must include the list of cosmetic `slsa` mentions examined and ruled out. Without that list, the negative is not durable.

### R2 — Close indirection paths explicitly

The gate may read SLSA level without the literal string `slsa-level` appearing at the gate site. Each path must be closed:

- job outputs:
  - `outputs.slsa-level`
  - `outputs.slsa`
  - similar aliases
- environment variables:
  - `$SLSA_LEVEL`
  - `$slsa_level`
  - similar aliases
- matrix dimensions:
  - `matrix: { slsa-level: [0, 1, 2, 3] }`
  - similar aliases
- `workflow_dispatch` inputs
- reusable-workflow parameters
- configuration files under `.github/`, `config/`, or `ci/`
- third-party actions that compute or emit SLSA level

Each path should be recorded as either:

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
