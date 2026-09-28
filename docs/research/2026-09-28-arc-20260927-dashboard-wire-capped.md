# What cap and demotion rule keeps wire-category articles at or below the configured share of the edition?

Status: crystallized 2026-09-28 from research line `arc-20260927-dashboard-wire-capped`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-arc-20260927-dashboard-wire-capped.md.

# Research line — crystallized record (contracting → closed)

**Line:** What cap and demotion rule keeps wire-category articles at or below the configured share of the edition?
**Lifecycle:** expanding → contracted → **crystallized** (this entry is the line's lasting record)

**Access note (carried forward, unchanged):** This crystallization, like both prior beats, ran without filesystem access to the llm-wiki vault or to the hngh kernel repository (`[redacted path] Per the line's own grounding rule, **no file paths are asserted as existing**. The only ground truth cited is the three vault pointers handed down in the prior material. Every kernel-side anchor is named as *required but unverified*. External sources are neither claimed nor needed for this line's core recommendations — the argument is self-contained except where marked.

---

## Findings (what the line established)

**F1 — The invariant is a ratio, not a count.**
The correct property is `wire_count(E) ≤ floor(share × size(E))`, evaluated per committed edition. A fixed-count cap is unsound because edition size varies; the allowance must be derived from the assembled edition size at commit time. This follows from the definition of the problem and requires no external citation.

**F2 — Cap enforcement and demotion are one coupled mechanism, not two gates.**
Demoting a non-wire article silently *raises* wire share; demoting a wire article frees budget that a refill pass can over-spend. Any design that checks the cap only at admission, or that treats demotion and refill independently, cannot hold the invariant. This is the line's central structural finding.

**F3 — The vault already records the two failure modes this line would reproduce if ignored.**
- `[[sources/verdict-rule-drift-two-surfaces]]` — a shared verdict rule drifted across two surfaces. If the cap surface and the verdict-demotion surface each compute "should this wire item be demoted?" independently, this exact drift recurs.
- `[[sources/outcome-demotion-at-two-consecutive-failures]]` — the recorded outcome establishes a demotion threshold (two consecutive failures) and leaves the oscillation question open: re-promotion after demotion can thrash under correlated failures.

**F4 — A precedent exists for the regression check this line needs.**
`[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]` records a conditional drift check on a behavioral property. The wire-share invariant is the numeric counterpart and can follow the same pattern.

---

## Recommendations (final form, R1–R5)

**R1 — Enforce at commit time, against live edition size.** Compute `floor(share × size(E))` from the assembled edition in the edition assembly/commit path, not from a configured slot count. *[anchor needed: assembly/commit entry point in the hngh kernel — expected near edition build or publish; unverified]*

**R2 — One post-mutation convergence loop, not an admission-only check.** After any mutation (add / promote / demote / refill): while `wire_count > floor(share × size)`, demote the lowest-ranked wire article with a deterministic tie-break (rank, then stable id); repeat until the invariant holds. The invariant becomes a fixpoint of every mutation rather than a gate on one path. *[anchor needed: mutation/refill call sites in hngh — unverified]*

**R3 — Single implementation of the demotion predicate, consumed by both surfaces.** The predicate — including the consecutive-failure counter per the outcome note — must live in one function/module called by both the cap surface and the verdict-demotion surface. This is the direct application of the verdict-rule-drift lesson. *[anchor needed: location of the existing verdict-demotion implementation in hngh — unverified]*

**R4 — Churn guard on re-promotion (design proposal, lower confidence).** Add hysteresis: a demoted wire item is ineligible for re-promotion for a cooldown window or until it clears a stricter bar than the one that demoted it. The hazard class (oscillation under correlated failures) is grounded in the recorded outcome note; the specific mechanism is not. Flagged as the least-crystallized recommendation.

**R5 — Numeric share-drift regression probe.** Per committed edition, record `wire_count / size` against the configured share and flag any edition over the line, patterned on the conditional drift check recorded in the scroll-behavior lesson note. *[anchor needed: wherever the existing drift check lives — vault note records the lesson, not the implementation location; unverified]*

---

## Open threads (enumerated, not dropped)

1. **Kernel anchors for R1–R3, R5.** Every enforcement point is located by role (assembly/commit, mutation/refill, verdict-demotion module) but not by file. A beat with filesystem access to `[redacted path] should resolve these before any implementation claim is made.
2. **Cooldown mechanism for R4.** Window-based vs. stricter-bar hysteresis is unresolved; the choice interacts with the two-consecutive-failures counter (does the counter reset on re-promotion?).
3. **Tie-break determinism under concurrent assembly.** R2's "rank, then stable id" assumes a total order at demotion time; whether edition assembly is single-threaded at that point is unverified.
4. **Configured share source of truth.** The line assumes a configured share exists; where it is configured (kernel config, edition parameters, vault-side) was never located.
5. **R5 alert semantics.** Flag-and-continue vs. fail-the-commit is a policy choice the line did not settle; the scroll-behavior precedent is conditional, suggesting flag-first.

---

## References

Ground truth actually cited (titles as given in prior material; paths unverified):

- `[[sources/verdict-rule-drift-two-surfaces]]` — "Shared verdict rule drifted across two surfaces" (llm-wiki vault)
- `[[sources/outcome-demotion-at-two-consecutive-failures]]` — "Consecutive bad-execution cancellation" (llm-wiki vault)
- `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]` — "Research Lesson: If drift is confirmed in the scroll behavior" (llm-wiki vault)

Named but unverified (no path asserted):

- hngh kernel repository: `[redacted path] (provided by the operator; not accessed in this or prior beats — all kernel-side anchors above remain open thread #1)
- `research-lines.tsv` (line state file, per operator)

No external sources were used. Where verification was impossible, this record says so rather than asserting. The line is closed in the contracted state; reopening should begin with open thread #1.
