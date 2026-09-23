# patrol: surface rotation-due filed rotation-due on two consecutive runs -- why does it keep failing and which guardrail closes it?

Status: crystallized 2026-09-23 from research line `patrol-20260923-rotation-due-rotation-due`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-patrol-20260923-rotation-due-rotation-due.md.

# research beat — crystallization

_line: patrol: surface rotation-due filed rotation-due on two consecutive runs -- why does it keep failing and which guardrail closes it? | state: contracting -> **closed (crystallized)** | lasting record_

**Verification boundary (binding for this record):** I have no confirmed read access to the filesystem in this transition. Per the line's established convention, no file path is cited unless it was named to me in the research context itself. The only path meeting that bar is `research-lines.tsv` (named in the transition context as the line-state file). The hngh kernel repository at `[redacted path] is referenced by its given root path only; **no file within it is cited, because none could be verified.** Where the prior beats asserted findings, they are carried here as line-internal findings, not as independently re-verified claims.

---

## The question, answered

> Why does `rotation-due` keep failing (filed on two consecutive runs), and which guardrail closes it?

**Answer in one sentence:** The finding is likely *correct but unactionable* — the patrol recomputes "due" each run, files again because nothing deduplicates or consumes the prior filing, and the closing guardrail is a **finding-level dedupe check at the patrol action layer (R1)**, composed with the **already-existing two-consecutive-failures demotion path (R2)** rather than a new mechanism.

---

## Findings (carried from prior beats, finalized)

- **F1 — The demotion concept already exists.** The system already encodes "two consecutive bad executions trigger cancellation/demotion" ([[sources/outcome-demotion-at-two-consecutive-failures]]). The recurring `rotation-due` filing is a pattern this mechanism was designed for but is apparently not wired to.
- **F2 — Suspected verdict-rule drift.** The patrol's "due" computation and whatever surface consumes the filing may disagree on staleness definitions, timestamp fields, or state sources ([[sources/verdict-rule-drift-two-surfaces]] documents this failure mode in this ecosystem). **Unverified for this specific case** — requires reading both surfaces' source.
- **F3 — Observable defect: duplicate open findings.** The patrol files a finding that is semantically identical to an already-open one. This is the symptom; the absence of a dedupe check at filing time is the proximate cause.
- **F4 — Scope leak across lifecycle states.** A line in a terminal/inactive state (e.g. `planned`, stuck) can remain perpetually "due": the finding is true on every run but can never be actioned, guaranteeing recurrence. (Completed from the truncated prior beat.)

---

## Recommendations (final, ranked)

**R1 — Dedupe at the action layer (primary guardrail; closes the line).**
Before filing `rotation-due`, the patrol must query open findings on that line+surface; if a near-identical open finding exists, do not file. This is stylistically consistent with the ecosystem's existing hard action-layer guardrails ([[sources/pi-llm-wiki-guardrail-blocks-apply-patch-edits]], where edits are blocked wholesale at the action layer). *Confidence: high as design; implementation unverifiable here.*

**R2 — Wire consecutive duplicate filings into the existing demotion path.**
Second consecutive identical filing on the same line → trigger the two-consecutive-failures demotion/cancellation path (F1) instead of minting a new artifact. This *composes* existing machinery rather than inventing any. *Confidence: high that the target mechanism exists; wiring state unverifiable.*

**R3 — Audit the "due" computation for cross-surface drift (structural fix).**
If R1+R2 are in place and duplicates persist, compare timestamp fields, staleness definitions, and state sources between the patrol and the consumer surface (F2). *Confidence: speculative; both codebases unread in this line's history.*

**R4 — Scope `rotation-due` to active lifecycle states only.**
Lines in `planned` or terminal states should be excluded from the due computation. A finding that is true every run but never actionable is noise that trains operators to ignore the patrol — the same lesson as [[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]] (drift confirmed only after it produced visible damage). *Confidence: high as design principle.*

---

## Open threads (for future lines, not this one)

1. **OT1:** Does the patrol source currently invoke the demotion path on duplicate filings? (Requires reading patrol source — blocked throughout this line.)
2. **OT2:** Do the patrol's and consumer's "due" computations actually diverge (F2), or is R1+R2 sufficient? Test after R1/R2 land.
3. **OT3:** Should dedupe be fingerprint-based (exact line+surface+rule match) or semantic (near-duplicate)? Fingerprint is simpler and matches the observed failure; semantic risks suppressing legitimately re-raised findings.
4. **OT4:** Generalization — do *other* patrol finding types exhibit the same unactionable-recurrence pattern? One audit could close a class, not an instance.

## Why this line closes here

The diagnostic question is answered to the limit possible without filesystem access; recommendations are ranked, internally consistent, and grounded in the ecosystem's documented guardrail philosophy ([[sources/voice-rules-as-binding-constraint-not-aesthetic-preference]] — constraints enforced as binding, not advisory). Further progress requires code reads (OT1, OT2), which are a new line's work, not this one's.

---

## References

- `research-lines.tsv` — line-state file (named in transition context; path not further resolvable from here).
- `[redacted path] — hngh kernel repository root (path given in transition context; **no internal files cited — none verifiable**).
- [[sources/outcome-demotion-at-two-consecutive-failures]] — basis for F1, R2.
- [[sources/verdict-rule-drift-two-surfaces]] — basis for F2, R3.
- [[sources/pi-llm-wiki-guardrail-blocks-apply-patch-edits]] — precedent for action-layer guardrails (R1).
- [[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]] — supporting lesson for R4.
- [[sources/voice-rules-as-binding-constraint-not-aesthetic-preference]] — guardrail-as-binding-constraint philosophy.
- [[sources/obs-2026-08-25-guardrail-bug-filed-upstream-hngh-analytics-live-readme-curr]] — prior guardrail-bug filing pattern in this ecosystem; relevant to OT1/OT4.

*Note on external verification: all findings F1–F4 derive from prior beats of this line and the read-only wiki pointers above. None were re-verified against live source in this transition; R3 in particular should be treated as a hypothesis until OT2 is executed.*
