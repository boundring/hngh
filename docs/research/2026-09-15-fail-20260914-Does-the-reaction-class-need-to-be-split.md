# Does the `reaction` class need to be split into `reaction-internal` and `reaction-external` to satisfy the "closed vocabulary" constraint in R1?

Status: crystallized 2026-09-15 from research line `fail-20260914-Does-the-reaction-class-need-to-be-split`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260914-Does-the-reaction-class-need-to-be-split.md.

# Final Structured Summary — `reaction` class split under R1 closed-vocabulary constraint

**Line:** Does the `reaction` class need to be split into `reaction-internal` and `reaction-external` to satisfy the "closed vocabulary" constraint in R1?
**State:** contracting → crystallized (this record is the line's lasting form)
**Date:** 2026-09-15

---

## Findings

### F1 — The question is conditional, not binary

The prior beat established that the answer to "must `reaction` be split?" depends on two independent variables:

1. **R1's scope.** Whether R1's closed-vocabulary constraint governs only internal state transitions (state variable names, transition identifiers) or also externally observable reaction outputs (effects emitted to the environment, rendered text, dispatched actions).
2. **The current reaction surface's output characteristics.** Whether the existing `reaction` class can produce unbounded or dynamically named outputs (arbitrary strings, runtime-constructed action names, unregistered payload identifiers).

If R1 constrains only internal state and the current surface is already finite in its observable outputs, a single `reaction` class satisfies R1 without splitting. If R1 covers observable effects *and* the current surface can emit unbounded vocabulary, then a structural separation is warranted — but the separation must be functional (closed external projection), not merely nominal (two class names).

### F2 — Class-splitting alone is insufficient

A split into `reaction-internal` and `reaction-external` satisfies R1 only if the external side is *actually closed*: every effect it can emit belongs to a finite, registered set. If the external layer can still produce arbitrary strings or dynamically named actions, R1 remains unsatisfied regardless of how many classes exist. The prior beat's contracted recommendation states this explicitly: "A split into `reaction-internal` and `reaction-external` is only a solution if the external side is actually closed."

### F3 — The operative requirement is vocabulary closure, not class topology

The real constraint R1 imposes is that the set of possible outputs (state transitions, effect names, payload schemas) be finite and enumerable. This can be satisfied by:
- two classes (`reaction-internal`, `reaction-external`),
- two modules within one class,
- two methods on one class,
- or a facade pattern over a single class.

The topology is an implementation detail. The invariant is: **no reaction path can produce a token, name, or identifier outside the registered vocabulary.**

### F4 — Machine-checkability is the enforcement mechanism

Closure must be verifiable by test, not by inspection. The prior beat identifies four failure conditions that tests should catch:
- an unregistered trigger name used in a reaction,
- an unregistered state field or value appearing in a transition,
- an unregistered effect name emitted externally,
- a payload schema not declared in the closed vocabulary.

Additionally, regression tests should confirm: every reaction output belongs to the registered effect set; no free-form identifiers appear in state transitions or effects; serialized reactions round-trip without inventing new vocabulary; any text output is generated from a registered template/token system rather than produced directly by unbounded logic.

### F5 — Conservative default when R1 scope is ambiguous

If R1's text does not clearly delineate whether "closed vocabulary" applies to internal state only or to observable effects as well, the prior beat recommends treating all externally observable reaction effects as part of the closed vocabulary. This is the conservative reading: it errs toward stricter compliance and can be relaxed if R1 is later clarified.

---

## Recommendations

For `hngh/hngh-automation` (the consuming repository), the crystallized recommendation is:

**Do not assume the `reaction` class must be split.** Proceed as follows:

1. **Determine R1 scope first.** Read R1's constraint text and determine whether it governs internal state variables/transitions only, or also externally observable outputs. This single determination gates all subsequent work.

2. **If R1 covers observable effects, separate responsibilities functionally.** The boundary is:
   - *Internal reaction:* maps trigger + current state → internal state delta.
   - *External projection:* maps internal state delta / current state → externally visible effects.
   
   Implement as two classes, two modules, two methods, or a facade — whichever fits the existing code structure. The requirement is that the external layer can only emit effects from a closed registry.

3. **Close the output vocabulary explicitly.** If reactions can currently produce arbitrary strings, dynamic action names, or unregistered payload identifiers, the split (if performed) must be accompanied by:
   - constraining outputs to finite tokens/templates, or
   - moving free-form rendering outside the R1-governed core and documenting that boundary.

4. **Make the vocabulary machine-checkable.** Add validation that fails when a reaction uses an unregistered trigger name, state field/value, effect name, or undeclared payload schema.

5. **Add regression tests for closure** as enumerated in F4 above.

6. **Do not treat class splitting as sufficient by itself.** Verify the external layer is actually closed after any split.

7. **If R1's scope remains ambiguous after step 1, record that ambiguity explicitly** and apply the conservative default (F5).

---

## Open Threads

| Thread | Status | Blocking dependency |
|--------|--------|---------------------|
| **R1 constraint text not yet read or quoted in this line.** The entire conditional structure of the finding hinges on R1's actual wording. No prior beat has cited R1's text verbatim. | Open | Access to the R1 specification document in the hngh kernel repository or its governance layer. |
| **Current `reaction` class surface not yet inspected.** Whether the existing code can produce unbounded outputs (arbitrary strings, dynamic names) is asserted as a possibility but not confirmed by reading the source. | Open | Reading the `reaction` implementation in `~/Projects/etc/hngh`. The prior beat flagged likely paths (`src/reaction.rs`, `lib/reaction.py`) as *unverified hypotheses* and explicitly declined to cite them. |
| **Whether a closed registry already exists.** If the codebase already maintains a finite set of registered effects/triggers/states, R1 may already be satisfied without any structural change. | Open | Inspection of existing registration tables or enum definitions in the kernel. |
| **External prior-art sources not independently verified.** The two vault pointers (`hngh-ceremony-loop-mechanics`, `voice-rules-as-binding-constraint-not-aesthetic-preference`) are referenced as context but their content was not read or confirmed in any beat of this line. | Open | Reading the vault entries if they exist at the cited paths. |
| **Interaction with other R-series constraints.** Whether R1's closed-vocabulary requirement interacts with other numbered constraints (R2, R3, …) that might independently force a structural separation is not addressed in this line. | Open | Full constraint set for the kernel's reaction layer. |

---

## Evidence Boundaries

**What is grounded in this record:**
- The logical structure of the conditional recommendation (F1–F5) is derived entirely from the prior beat's contracted analysis, which was itself a reasoned argument about what R1 *would* require under different scopes. This is an internal consistency argument, not an empirical claim about the codebase.
- The recommendation to make vocabulary machine-checkable and to add regression tests is a standard software-engineering practice; it does not depend on any external source.

**What is NOT grounded and is explicitly flagged as unverifiable:**
- **No concrete file paths in `~/Projects/etc/hngh` are cited.** The prior beat stated: "I cannot verify specific file paths inside `~/Projects/etc/hngh` from the supplied material, so no concrete repository file paths are cited here." This line inherits that limitation. Any path mentioned (e.g., `src/reaction.rs`, `lib/reaction.py`) in earlier beats is an *unverified hypothesis* and must be confirmed before acting on it.
- **No external sources beyond the two vault pointers are verified.** The prior-art entries are named but their content was not independently read or confirmed in this line.
- **The actual text of R1 is not quoted anywhere in this line's material.** All findings about R1's scope are conditional on what R1 *says*, which has not been established in the supplied record.

**What would close the open threads:**
- Reading R1's constraint text in the kernel repository (or its governance/specification layer).
- Reading the `reaction` class implementation to determine whether its output surface is bounded or unbounded.
- Checking for existing registration tables, enums, or closed sets that may already satisfy R1.

---

## References

1. **Prior material on this line:** "research beat 2026-09-15" (provided in the prompt as prior material). Contains the contracted recommendation and evidence-status disclaimer.
2. **Vault pointer:** `[[sources/hngh-ceremony-loop-mechanics]]` — referenced as context for hngh dogfood ceremony mechanics (closed vocabularies, path positioning). Content not independently verified in this line.
3. **Vault pointer:** `[[sources/voice-rules-as-binding-constraint-not-aesthetic-preference]]` — referenced as context for voice rules as binding constraints. Content not independently verified in this line.
4. **Task statement** naming the kernel repository at `~/Projects/etc/hngh`. No file paths within that repository are cited in this record because none could be verified from the supplied material.
5. **R1 constraint text.** Not cited. The actual wording of R1's "closed vocabulary" constraint has not been quoted or located in any beat of this line. All findings about R1's scope are conditional on its content, which remains an open thread.
