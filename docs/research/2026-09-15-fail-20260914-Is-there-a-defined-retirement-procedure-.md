# Is there a defined retirement procedure in `research-lines.tsv` or governance docs that allows closing `patrol:automation-gate` without a code fix if the gate is deemed obsolete?

Status: crystallized 2026-09-15 from research line `fail-20260914-Is-there-a-defined-retirement-procedure-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260914-Is-there-a-defined-retirement-procedure-.md.

## Contracted record

**Line:** Is there a defined retirement procedure in `research-lines.tsv` or governance docs that allows closing `patrol:automation-gate` without a code fix if the gate is deemed obsolete?  
**Lifecycle state:** contracting  
**Final disposition:** The line is contracted into a decision procedure and unresolved verification threads. No verified retirement procedure can be asserted from the material available in this turn.

---

## Epistemic status

This summary does not claim to have read `research-lines.tsv`, any governance document, the llm-wiki vault note bodies, or `/home/bricker/Projects/etc/hngh`. The only concrete paths cited are the two named in the task itself:

- `research-lines.tsv`
- `/home/bricker/Projects/etc/hngh`

All other statements are either structural reasoning about what a retirement procedure must be, or greppable verification steps that remain open.

---

## Findings

### F1 — The line bundles two separable questions

The research line is not one question but two:

1. **Procedural question:** Does the line-tracking system define a closure path that does not require a code fix?
2. **Substantive question:** Is `patrol:automation-gate` actually obsolete, superseded, or otherwise no longer requiring a code fix?

These must be answered in order. A retirement procedure is only usable if the substantive claim it applies to is established. Conversely, the substantive claim is only closable if there is a procedure or convention that can record it.

### F2 — No verified retirement procedure is established from the supplied material

The supplied material does not demonstrate that `research-lines.tsv` contains a terminal state such as:

- `retired`
- `obsolete`
- `superseded`
- `dropped`
- `wontfix`
- `closed`

nor does it demonstrate that any governance document defines closure without a code fix.

Therefore, the procedural question remains open.

### F3 — Absence in supplied material is not evidence of absence in the repository

The fact that no retirement procedure appears in the prior material does not prove that no such procedure exists in `research-lines.tsv` or in governance documentation under `/home/bricker/Projects/etc/hngh`. It only means that this turn cannot verify one.

### F4 — A terminal state without a code fix is plausible, but unconfirmed

For a self-governing automation harness, it is structurally plausible that a line can be closed as obsolete, superseded, invalid, or no longer actionable without requiring a code fix. Such closure would normally require:

- an explicit terminal state,
- a reason field or equivalent record,
- an audit trail showing who closed the line and why,
- preservation of the row rather than deletion.

However, that plausibility is not evidence that the procedure exists in this repository.

### F5 — The substantive obsolescence claim is not established

The prior material does not establish that `patrol:automation-gate` is obsolete. It only frames the question of whether it could be closed without a code fix if deemed obsolete. That judgment remains separate from the procedural question and remains open.

---

## Recommendations

### R1 — Inspect `research-lines.tsv` for terminal-state vocabulary

Read `research-lines.tsv` directly, including its header row, column comments if any, and all distinct values appearing in its state column.

If any row already carries a terminal value other than “resolved” or “fixed,” such as:

- `retired`
- `obsolete`
- `superseded`
- `dropped`
- `wontfix`
- `closed`

then the procedural question may be answered **yes** by demonstrated convention, even in the absence of a written governance document. In a line-tracking system that is itself the governance artifact, precedent in the data can function as a defined procedure.

### R2 — Search `/home/bricker/Projects/etc/hngh` for governance text

If `research-lines.tsv` does not reveal a terminal state, search `/home/bricker/Projects/etc/hngh` for retirement-relevant terms across documentation, TSV files, and any governance or process text. Useful search terms include:

- `retire`
- `obsolete`
- `superseded`
- `close line`
- `lifecycle`
- `research-lines`
- `terminal state`
- `no fix required`
- `wontfix`

A governance document that defines states but no exit condition is an incomplete specification, not necessarily a prohibition. Absence of a procedure is not evidence that closure is forbidden, but it does mean the closure cannot be treated as already defined.

### R3 — If no procedure exists, record the retirement decision explicitly

If no existing procedure is found, the cleanest closure-without-fix is to create or apply an explicit retirement record rather than silently deleting the line.

The record should include:

- line identifier: `patrol:automation-gate`
- terminal state: one of the repository’s recognized terminal states, if any; otherwise a newly defined state such as `retired`, `obsolete`, or `superseded`
- closure basis: obsolete, superseded, invalid, no longer actionable, or no code fix required
- date
- actor or process responsible for the decision
- evidence pointer to the substantive judgment that the gate is obsolete
- explicit statement that no code fix is required

### R4 — Do not delete the line row

If `patrol:automation-gate` is closed without a code fix, the row should not be deleted. The lasting record should preserve:

- why the line was opened,
- why it was retired,
- what evidence supported the retirement,
- when and by whom it was retired.

Deletion would destroy the audit trail that distinguishes “closed as obsolete” from “lost or forgotten.”

### R5 — Keep the procedural and substantive questions separate

The final record should not conflate:

- “the system allows closure without a code fix,” with
- “this particular gate is obsolete.”

A retirement procedure may exist even if `patrol:automation-gate` is not yet established as obsolete. Conversely, the gate may be substantively obsolete even if no formal procedure exists to record that fact. The line’s lasting value is in preserving that distinction.

---

## Open threads

1. **Unverified:** Does `research-lines.tsv` contain a terminal state that permits closure without a code fix?
2. **Unverified:** Do governance documents under `/home/bricker/Projects/etc/hngh` define a retirement procedure for research lines?
3. **Unverified:** Is `patrol:automation-gate` substantively obsolete, superseded, or no longer requiring a code fix?
4. **Unresolved:** If no procedure exists, should the repository introduce an explicit terminal state and closure record for obsolete lines?
5. **Unresolved:** What is the minimum audit metadata required to close a line without a code fix while preserving the line’s lasting record?

---

## Final answer to the line

No verified defined retirement procedure is established in the supplied material. The question remains open pending direct inspection of `research-lines.tsv` and any governance documentation under `/home/bricker/Projects/etc/hngh`. If such a procedure exists, it must define a terminal state whose semantics are “closed because obsolete,” “closed because superseded,” or “closed without fix required.” If no such procedure exists, the repository should not silently close the line; it should record the retirement decision explicitly and preserve the row as an audit trail.

---

## References

- `research-lines.tsv` — named in the task as the line-state store; existence and contents not independently verified in this turn.
- `/home/bricker/Projects/etc/hngh` — named in the task as the hngh kernel repository root; not inspected in this turn.
