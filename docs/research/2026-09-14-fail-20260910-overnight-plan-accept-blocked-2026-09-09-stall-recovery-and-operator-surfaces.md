# Why did plan 2026-09-09-stall-recovery-and-operator-surfaces fail auto-accept twice with "step 1 has no Verification line", and is the acceptance blocker still open or already resolved by the plan acceptance and step-1 audit-close?

Status: crystallized 2026-09-14 from research line `fail-20260910-overnight-plan-accept-blocked-2026-09-09-stall-recovery-and-operator-surfaces`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260910-overnight-plan-accept-blocked-2026-09-09-stall-recovery-and-operator-surfaces.md.

# Final Structured Summary — `2026-09-09-stall-recovery-and-operator-surfaces` auto-accept blocker

**Line state:** contracting → closed (this record)
**Date of crystallization:** 2026-09-14

---

## Findings

### F1 — The failure was deterministic, not transient

The plan `2026-09-09-stall-recovery-and-operator-surfaces` failed auto-accept **twice** with the identical error string **"step 1 has no Verification line."** (stated in the line itself). A repeated, byte-identical parser error is a deterministic input condition: the step-1 block in the plan document lacks a `Verification:` field, and the acceptance parser rejects it on every pass until that field appears. It does not heal by retry.

### F2 — Two subsequent events are on record but their effect on the blocker is unconfirmed

The line records two later events: a **plan acceptance** and a **step-1 audit-close**. Neither event's mechanism is documented in the material available to this line. The critical distinction is whether the plan acceptance was a `parse_pass` (the parser itself accepted after the input changed) or an operator **override** (a human accepted the plan while the parse error remained). An override does not fix the input; the next auto-accept pass re-fires the identical error. Similarly, the step-1 audit-close may live in a separate log that the acceptance parser never consults, leaving the blocker open by construction.

**I cannot verify which path produced the plan acceptance or whether the audit-close wrote back to the plan document.** The prior material for this beat explicitly states: "I have no live file access in this turn." No plan text, acceptance log, or step-1 audit record was present in the handed material. This remains an open evidentiary gap, not a resolved fact.

### F3 — The mid-line Verification block is a known failure mode in hngh

The prior-art pointer `[[sources/mid-line-verification-block-triggers-long-acceptance-pending]]` ("Mid-line Verification fi…") documents that a missing Verification field mid-line triggers a long acceptance-pending state. This is consistent with the observed behavior: the plan sat in auto-accept pending while the parser repeatedly rejected step 1, rather than failing fast at authoring time.

### F4 — The stall-lessons source corroborates the acceptance-parsing dimension

The prior-art pointer `[[sources/hngh-2026-09-09-stall-lessons]]` ("Hngh stall lessons: model burn, acceptance parsing, orp…") names "acceptance parsing" as one of the lesson categories extracted from this exact stall event. This confirms the Verification-line failure was recognized as a distinct acceptance-parsing issue in the post-stall review, not merely a model-burn symptom.

### F5 — Evidence-gated disposition is the governing principle

The prior-art pointer `[[sources/backlog-disposition-sweep-reduces-accepted-plans-by-half]]` ("Evidence-gated disposition s…") frames disposition as gated on evidence. A missing Verification line *is* a missing-evidence condition: the step asserts an action but provides no checkable criterion for completion. The auto-accept parser is correctly refusing to accept an unevidenced step.

---

## Recommendations

These are directed at the hngh / hngh-automation acceptance pipeline. They are grounded in the observed error and the prior-art pointers named above; I flag where a recommendation would require verifying a file path I cannot confirm.

**R1 — Fail at authoring, not at auto-accept.**
Require a `Verification:` line on every step (step 1 first) as a hard pre-condition for a plan to be *eligible* for auto-accept. Emit the exact same error string the parser uses ("step N has no Verification line") so the operator's linter and the acceptance parser can never disagree. This converts a mid-line stall into an authoring-time rejection.
*(Grounded in F1; consistent with the evidence-gated disposition principle in `[[sources/backlog-disposition-sweep-reduces-accepted-plans-by-half]]`.)*

**R2 — Tag acceptance events as `parse_pass` vs `override`.**
The single most likely reason "plan acceptance" did not clear the blocker is that it was an operator override. An override accepts the plan without fixing the input, so the next auto-accept pass re-fires the identical error. The acceptance record must carry which path produced it; only `parse_pass` may close a Verification blocker.
*(Grounded in F2; this is the direct mechanism by which the blocker would remain open despite an apparent "acceptance" event.)*

**R3 — Make step-1 audit-close write back to what the parser reads.**
Closing step 1 must be visible to the re-parser: either the plan document gains a `Verification:` line on step 1, or an audit artifact the parser consults records it. If the close lives only in a separate log the parser never reads, the blocker is still open by construction.
*(Grounded in F2; direct counter to the long-pending behavior in `[[sources/mid-line-verification-block-triggers-long-acceptance-pending]]`.)*

**R4 — Surface Verification blocks immediately with step index and field name.**
Do not let a mid-line missing-Verification condition ride to auto-accept and produce a long acceptance-pending state. Raise it at the point of detection.
*(Grounded in F3; per `[[sources/mid-line-verification-block-triggers-long-acceptance-pending]]`.)*

**R5 — Give plan steps a machine-checkable schema.**
Fields: `step` (index), `action`, `verification` (required), `evidence_ref` (optional). Auto-accept validates the schema before any semantic pass. A step missing `verification` is structurally ineligible, not merely semantically weak.
*(Grounded in F1 and F5; the schema makes R1 mechanically enforceable.)*

**R6 — Post-stall review must name the acceptance-parsing lesson explicitly.**
The stall-lessons source already names "acceptance parsing" as a category (`[[sources/hngh-2026-09-09-stall-lessons]]`). The lessons document should carry the specific error string and the two-event sequence (plan acceptance + audit-close) so that future operators can distinguish `parse_pass` from `override` without re-deriving it.
*(Grounded in F4.)*

---

## Open Threads

These are threads this line cannot close from the material available to it. They remain open for any subsequent beat or operator action.

**O1 — Was the plan acceptance a `parse_pass` or an `override`?**
The line records that a plan acceptance occurred but does not record its mechanism. If it was an override, the blocker is still open: the next auto-accept pass will re-fire "step 1 has no Verification line." If it was a `parse_pass`, then step 1 must have gained a `Verification:` line between the second failure and the acceptance, and the blocker is resolved. **I cannot verify which.** No plan text or acceptance log was present in the material handed to this beat.

**O2 — Did the step-1 audit-close write back to the plan document?**
If the audit-close produced a `Verification:` line in the plan's step 1, the parser input changed and the blocker is resolved. If the close lives only in a separate audit log that the acceptance parser does not consult, the blocker remains open by construction (R3). **I cannot verify which.** No audit artifact was present in the material.

**O3 — Is there a file under `/home/bricker/Projects/etc/hngh` that records the acceptance mechanism?**
The line asks for grounding in the hngh kernel repository. The prior material for this beat explicitly states no live file access was available, and I have not been handed any file paths from that repository. **I cannot name a concrete file path in `/home/bricker/Projects/etc/hngh` with confidence.** Any such claim would be unverified. This thread closes when an operator or a subsequent beat reads the acceptance log (or equivalent) and records whether the mechanism was `parse_pass` or `override`.

**O4 — Is the auto-accept parser's error string stable across versions?**
The recommendation R1 depends on the linter and the parser emitting the same string. If the parser's error format changes between hngh versions, a linter hard-coded to the old string will silently pass plans the parser rejects. **I cannot verify the parser's current error-string implementation** without file access to the acceptance module in `/home/bricker/Projects/etc/hngh`. This thread closes when the parser source is read and the string is confirmed or the linter is updated to match.

---

## Disposition of the Line's Central Question

> *Is the acceptance blocker still open or already resolved by the plan acceptance and step-1 audit-close?*

**The line cannot answer this from the material available.** The two events (plan acceptance, step-1 audit-close) are on record as having occurred, but their mechanism is undocumented in the material. The blocker is **resolved if and only if** the plan document's step 1 now contains a `Verification:` line that the acceptance parser reads; it is **still open** if the acceptance was an override or the audit-close lives outside the parser's input. The distinguishing evidence is a single file read (the plan document or the acceptance log), which this beat did not have access to perform.

The line therefore closes with the blocker's status **undetermined pending O1/O2**, and with the structural recommendations R1–R6 in force so that the next occurrence of this failure mode is caught at authoring time rather than stalling mid-line.

---

## References

All references below are prior-art pointer titles from the llm-wiki vault as supplied to this beat. They are read-only pointers; I have not verified their full text beyond the truncated titles shown in the line's prior material. No file paths under `/home/bricker/Projects/etc/hngh` are cited because I cannot confirm their existence from the material available to this beat.

- `[[sources/hngh-2026-09-09-stall-lessons]]` — "Hngh stall lessons: model burn, acceptance parsing, orp…" (directly relevant: names acceptance parsing as a lesson category for this exact event)
- `[[sources/mid-line-verification-block-triggers-long-acceptance-pending]]` — "Mid-line Verification fi…" (directly relevant: documents the long-acceptance-pending failure mode triggered by a missing Verification field)
- `[[sources/backlog-disposition-sweep-reduces-accepted-plans-by-half]]` — "Evidence-gated disposition s…" (tangentially relevant: frames disposition as gated on evidence; a missing Verification line is a missing-evidence condition)
- `[[sources/SRC-2026-08-24-030]]` — "Case Study: Overnight Multi-Agent Sprint (2026-08-24)" (contextual; not directly load-bearing for this line's findings)
- `[[sources/chartlibrary-io-developers-api]]` — "chartlibrary.io free REST/MCP market-history research" (not relevant to this line)
- `[[sources/evomap-ai-agent-experience-network]]` — "evomap.ai agent experience network (GEP), lo…" (not relevant to this line)

No file paths in `/home/bricker/Projects/etc/hngh` are cited. The prior material for this beat explicitly states no live file access was available, and I have not been handed any such paths. Any claim about a specific file in that repository would be unverified from the material at hand.
