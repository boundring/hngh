# What are OT1 and OT2 concretely (tracker entries, owners, acceptance criteria), and is the blocking mechanism linking them to the dedupe/demotion hypotheses written down anywhere verifiable?

Status: crystallized 2026-09-24 from research line `fail-20260924-What-are-OT1-and-OT2-concretely-tracker-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260924-What-are-OT1-and-OT2-concretely-tracker-.md.

# research beat 2026-09-24 — final contraction: OT1/OT2 line

_line: What are OT1 and OT2 concretely (tracker entries, owners, acceptance criteria), and is the blocking mechanism linking them to the dedupe/demotion hypotheses written down anywhere verifiable? | state: contracting → closed | model: kimi:k3-256k | wall_s: 49.0_

---

## Findings

### F1 — OT1/OT2 are not concretely written down anywhere verifiable.

This is the line's central finding, confirmed across two consecutive transitions without resolution. No tracker entry, no owner assignment, no acceptance criteria, no blocking linkage — nothing that satisfies the line's own verifiability standard has been located. The repository paths I can cite with confidence are:

- `research-lines.tsv` (this line's state pointer; confirmed to exist)
- `[redacted path] (kernel repository root; cited in prior beats)

I cannot confirm the existence of any sibling tracker in `hngh-automation` or any other vault. That is an explicit gap, not an oversight.

### F2 — The blocking mechanism is not written down anywhere verifiable.

A plausible chain was reconstructed across four llm-wiki vault sources in prior beats:

1. `sources/hngh-2026-09-09-stall-lessons` — stall lessons (model burn, acceptance parsing, orp)
2. `sources/mid-line-verification-block-triggers-long-acceptance-pending` — mid-line verification triggers
3. `sources/outcome-demotion-at-two-consecutive-failures` — consecutive bad-execution cancellation
4. `sources/supervision-must-be-hngh-native` — supervision must be a mechanism, not prose

But a chain reconstructable only by reading four notes in sequence is not a written-down mechanism. The honest answer to the line's second question is: **no**.

### F3 — The burden of proof has shifted.

Per `sources/outcome-demonstration-at-two-consecutive-failures`, the hypothesis that OT1/OT2 are concretely written down is at its demotion threshold. Two consecutive beats failing to locate the artifacts means the line's next work must be *production*, not *audit*.

### F4 — The line should not attempt a third audit-style beat.

This is a self-imposed boundary. Without confirmed read access to the hngh kernel repository, further transitions on this line will reproduce F1 and F2. The line's next transition must either run with confirmed access or accept closure.

---

## Recommendations

**R1 — Mint OT1/OT2 as first-class tracker entries, or stop citing them.**

If OT1/OT2 exist only as oral shorthand in research notes, they fail the line's own verifiability standard. Concretely: add rows to `research-lines.tsv` (or the appropriate sibling tracker in hngh-automation) with an explicit schema: `id | owner | acceptance_criteria | state | blocking`. If they already exist somewhere in the kernel repo, the next transition's only job is to cite the path. Two unverified beats is the signal to stop auditing and start writing.

**R2 — Write the blocking mechanism as one artifact, not four pointers.**

The prior beat reconstructed a plausible chain across four vault sources, but a chain reconstructable only by reading four notes in sequence is not a written-down mechanism. Recommendation: a single rule file in hngh-automation stating, in one place, something of the form *"OT1/OT2 acceptance pending beyond threshold ⇒ mid-line verification block; two consecutive bad executions ⇒ outcome demotion"* with links back to the four sources as rationale. Until that file exists, the honest answer to this line's second question is **no — the blocking mechanism is not written down anywhere verifiable**.

**R3 — Make the block executable, per the hngh-native supervision source.**

`sources/supervision-must-be-hngh-native` argues supervision must be a mechanism, not prose. Applied here: the OT1/OT2 block and the demotion trigger should be an automated check in hngh-automation (e.g., a sweep that reads tracker state and enforces the block), not a convention maintainers remember. I cannot confirm what automation harness exists in the kernel repo, so the integration point is unspecified — that is an explicit gap, not an oversight.

**R4 — Acceptance criteria for OT1/OT2 must themselves satisfy the mid-line verification lesson.**

`sources/mid-line-verification-block-triggers-long-acceptance-pending` exists precisely because long-pending acceptances stall. Whatever acceptance criteria get written for OT1/OT2 should include a time-in-state bound that triggers the R2 block, closing the loop between the two prior-art pieces.

**R5 — Re-scope the line's next transition.**

This line should not attempt a third audit-style beat without repository access. Either the next transition runs with confirmed read access to the hngh kernel repository, or this line closes here with the findings above as its lasting record.

---

## Open Threads

| Thread | Status | Notes |
|--------|--------|-------|
| OT1/OT2 concrete artifacts | Open | Requires production, not audit. See R1. |
| Blocking mechanism written down | Open | Requires single artifact, not four pointers. See R2. |
| hngh-automation integration point | Open | Cannot verify from current access. See R3. |
| Repository read access | Open | Confirmed unavailable. See F4. |

---

## References

**Repository paths (cited with confidence):**
- `research-lines.tsv` — this line's state pointer; confirmed to exist
- `[redacted path] — kernel repository root; cited in prior beats

**Prior art (llm-wiki vault; read-only pointers):**
- `sources/hngh-2026-09-09-stall-lessons` — Hngh stall lessons: model burn, acceptance parsing, orp
- `sources/mid-line-verification-block-triggers-long-acceptance-pending` — Mid-line Verification triggers for long acceptance pending
- `sources/outcome-demonstration-at-two-consecutive-failures` — Consecutive bad-execution cancellation criteria
- `sources/supervision-must-be-hngh-native` — Supervision patterns must become Hngh-native mechanisms

**External sources:**
- None cited. All claims are grounded in the repository and prior art above.

---

_line: What are OT1 and OT2 concretely (tracker entries, owners, acceptance criteria), and is the blocking mechanism linking them to the dedupe/demotion hypotheses written down anywhere verifiable? | state: closed | model: kimi:k3-256k | wall_s: 49.0_
