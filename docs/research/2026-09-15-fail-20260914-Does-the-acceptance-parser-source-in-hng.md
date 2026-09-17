# Does the acceptance parser source in hngh/hngh-automation contain a hardcoded "has no Verification line" rejection, and does it re-validate on every auto-accept pass regardless of prior operator overrides?

Status: crystallized 2026-09-15 from research line `fail-20260914-Does-the-acceptance-parser-source-in-hng`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260914-Does-the-acceptance-parser-source-in-hng.md.

# Contracted Research Line: Acceptance Parser Verification Gate & Re-Validation Semantics

**Line:** Does the acceptance parser source in `hngh/hngh-automation` contain a hardcoded "has no Verification line" rejection, and does it re-validate on every auto-accept pass regardless of prior operator overrides?

**State:** contracting (final)
**Date:** 2026-09-14

---

## Findings

### What the prior material establishes

The vault record consistently treats "acceptance parsing" as a known operational failure point. The stall-lessons note (`hngh-2026-09-09-stall-lessons`) names it explicitly alongside model burn and orphaned processes, indicating the parser has produced observable stalls in practice. The mid-line verification block note (`mid-line-verification-block-triggers-long-acceptance-pending`) documents a concrete failure mode: when a plan lacks a Verification line, acceptance enters a long-pending state rather than failing fast. This confirms that **a verification-line check exists somewhere in the acceptance pipeline** and that its absence has real operational consequences (plans stuck in pending).

The prior-art landscape synthesis (`hngh-prior-art-landscape-2026-08`) situates `hngh-automation` as an overnight harness built on top of the `hngh` kernel, with the observation note (`obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled`) confirming the harness was built, verified, and enabled as a unit. The backlog disposition sweep note (`backlog-disposition-sweep-reduces-accepted-plans-by-half`) shows that acceptance outcomes are gated on evidence quality, reinforcing that verification is not merely cosmetic but load-bearing in the accept/reject decision.

### What remains unconfirmed

**Neither of the two specific technical questions has been resolved by direct source inspection.** The prior expanding beat explicitly flagged this limitation: it could not execute commands or read the file system at `~/Projects/etc/hngh` or within `hngh/hngh-automation`. All inferences about parser internals (hardcoded string vs. schema validation, stateless re-validation vs. cached override) were framed as hypotheses grounded in architectural reasoning, not in confirmed source reads.

Specifically:

1. **Hardcoded rejection string:** The prior beat hypothesized that "has no Verification line" is more likely a schema or validator-level check (possibly in a shared library within the `hngh` kernel that `hngh-automation` imports) than a literal string constant in an automation parser file. This hypothesis is reasonable given the architecture but **is not confirmed by any cited source**. No specific file path, function name, or line number has been verified to exist.

2. **Re-validation semantics:** The prior beat hypothesized stateless re-validation (the parser checks current plan state on every pass, with no memory of prior operator overrides). This is the default expectation for a stateless validation step but **has not been confirmed by tracing an actual call stack or identifying a caching/override mechanism**. No specific override-persistence file, database table, or bypass flag has been located.

### Operational signal

The fact that the verification block produces *long acceptance-pending* states (per the mid-line note) rather than immediate rejection is itself a weak signal about re-validation behavior: if the parser simply rejected on first pass and stayed rejected, the pending state would not persist. The persistence of the pending state suggests either (a) the check is re-evaluated on each auto-accept pass and the plan remains pending until the Verification line is added, or (b) there is a separate polling/retry mechanism. Both interpretations are consistent with the observed behavior; neither has been confirmed against source.

---

## Recommendations

These are the concrete actions that would resolve the two open questions. They are ordered by expected information yield per unit effort.

### R1: Grep for the rejection string across both repositories

```bash
grep -rn "has no Verification line" ~/Projects/etc/hngh/ hngh/hngh-automation/
grep -rn "no.*[Vv]erification.*line" ~/Projects/etc/hngh/ hngh/hngh-automation/
grep -rn "verification.line" ~/Projects/etc/hngh/ hngh/hngh-automation/ --include="*.py" --include="*.rs" --include="*.ts" --include="*.go"
```

This directly answers question 1 (hardcoded string or not) and locates the exact file. If the string appears in a schema definition, a validator module, or a test fixture rather than in parser logic, that refines the architectural understanding. **Confidence in this action's value: high.** The grep is cheap and disambiguating.

### R2: Trace the auto-accept entry point and its validation call

Once R1 locates the check, identify the function or module that invokes it during an auto-accept pass. Specifically:

- Find the auto-accept loop or scheduler in `hngh/hngh-automation` (the overnight harness observation note confirms this component exists and runs on a schedule).
- Trace whether the verification check is called unconditionally per pass or gated by a state flag (e.g., "already validated," "operator override active").
- Look for any persistence of operator overrides: search for terms like `override`, `waiver`, `bypass`, `acknowledged`, `force_accept` in both repositories.

This directly answers question 2. **Confidence in this action's value: high.** The call-stack trace is the definitive test.

### R3: Check for a shared validation library in the kernel

The prior beat's hypothesis that the check lives in the `hngh` kernel (shared with automation) is testable:

```bash
# Look for a validation or parser module in the kernel
find ~/Projects/etc/hngh -type f \( -name "*valid*" -o -name "*parse*" -o -name "*accept*" \) | head -40
# Check if hngh-automation imports from the kernel
grep -rn "from.*hngh\|import.*hngh\|require.*hngh" hngh/hngh-automation/ --include="*.py" --include="*.rs" --include="*.ts"
```

If the parser is a kernel component, the "hardcoded string" question shifts from automation to kernel, and the re-validation question depends on how the kernel exposes its validation API (pure function vs. stateful service). **Confidence in this action's value: medium-high.** It refines the architectural model but may not be necessary if R1 already locates the string.

### R4: Inspect operator-override persistence surfaces

If R2 reveals that overrides exist, determine where they are stored:

- Plan metadata annotations (in-repo file or database)
- A dedicated override/waiver table or config
- An in-memory flag that resets on restart (which would confirm stateless re-validation)

The absence of any such surface is itself a finding: it would confirm that operator overrides are not persisted and the parser re-validates unconditionally. **Confidence in this action's value: medium.** Dependent on R2's outcome.

---

## Open Threads

1. **The exact location and nature of the "has no Verification line" check is unknown.** It could be a literal string in a parser, a schema constraint, a validator function return value, or a test assertion. The prior material's hypothesis (schema/validator-level) is reasonable but unconfirmed. R1 resolves this.

2. **The re-validation semantics are unknown.** Whether the auto-accept pass re-runs validation unconditionally, respects a cached "validated" state, or honors operator overrides has not been determined by source inspection. The operational evidence (long-pending states) is consistent with unconditional re-validation but does not prove it. R2 resolves this.

3. **The relationship between `hngh-automation` and the `hngh` kernel's validation layer is architecturally unclear.** The prior-art landscape describes automation as a harness on top of the kernel, but whether the acceptance parser lives in automation, in the kernel, or in a shared library consumed by both has not been confirmed. R3 addresses this.

4. **The interaction between the backlog disposition sweep and verification gating is unexplored.** The sweep note shows that accepted plans are reduced by half through evidence-gated disposition. Whether the Verification-line check is part of this same gate or a separate upstream check is unknown. This is a lower-priority thread but may clarify the validation pipeline's layering.

5. **No specific file paths in either repository have been verified to exist.** All prior material references are vault notes (llm-wiki), not source files. The contracted record does not assert the existence of any particular `.py`, `.rs`, `.ts`, or other source file. Any future beat that cites a specific path must do so after direct inspection.

---

## Disposition

This line is **contracted with two open technical questions unresolved**. The architectural and operational context is well-established from the vault record: the verification gate exists, it has produced real stalls, and the auto-accept harness is a known component. What is missing is source-level confirmation of (a) where the rejection string lives and (b) whether re-validation is unconditional. These are resolvable by the grep-and-trace actions in R1–R3, which require direct file-system access that was not available during the expanding beat.

The line's lasting value is the **operational signal**: the Verification-line check is a known, recurring stall point with observable consequences (long-pending acceptance states), and its exact mechanics (hardcoded vs. schema, stateless vs. override-aware) are the remaining unknowns that determine whether operator overrides are durable or illusory.

---

## References

- `[[sources/hngh-2026-09-09-stall-lessons]]` — Names "acceptance parsing" as a stall lesson alongside model burn and orphaned processes.
- `[[sources/mid-line-verification-block-triggers-long-acceptance-pending]]` — Documents that a missing Verification line causes acceptance to enter a long-pending state.
- `[[syntheses/hngh-prior-art-landscape-2026-08]]` — Broader architectural context for hngh kernel and automation harness relationship.
- `[[sources/SRC-2026-08-24-025]]` — Hngh Prior-Art Landscape Record (2026-08-24).
- `[[sources/backlog-disposition-sweep-reduces-accepted-plans-by-half]]` — Evidence-gated disposition sweep; shows acceptance outcomes are quality-gated.
- `[[sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled]]` — Confirms the overnight automation harness was built, verified, and enabled as a unit.

*No file paths within `~/Projects/etc/hngh` or `hngh/hngh-automation` are cited in this record because none have been verified to exist by direct inspection. All references above are vault notes (llm-wiki pointers) provided in the prior material.*
