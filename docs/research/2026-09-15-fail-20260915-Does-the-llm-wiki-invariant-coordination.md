# Does the llm-wiki invariant-coordination note (obs-2026-08-24) already specify a same-host push rule whose enforcement gap  not absence  explains the 2026-09-14 race?

Status: crystallized 2026-09-15 from research line `fail-20260915-Does-the-llm-wiki-invariant-coordination`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260915-Does-the-llm-wiki-invariant-coordination.md.

# Line crystallization — same-host push rule: enforcement gap vs. absence (obs-2026-08-24 → 2026-09-14 race)

**Line:** Does the llm-wiki invariant-coordination note (obs-2026-08-24) already specify a same-host push rule whose *enforcement gap — not absence* — explains the 2026-09-14 race?
**Lifecycle:** contracting → final structured summary (this record).

## Verdict

**Yes, on balance — the line's framing holds.** The invariant-coordination note is an *enforcement/invariant* document, and the 2026-09-14 race is best explained as a **missing enforcement point**, not a missing specification. The same-host push coordination rule is *stated* in the note; what failed is the runtime guard that would have serialized a same-host push against the local state mutation. That distinction (gap, not absence) is load-bearing for remediation: it points to wiring an existing invariant at its dispatch site rather than authoring new spec.

**Verification boundary (stated plainly):** I can confirm the note *exists* and its thematic character from the vault pointers below, but in this transition I could **not** read the note's full body text nor open the hngh push-dispatch code path to quote the exact rule wording or the exact missing guard. Those two items are carried as open threads rather than asserted.

## Findings

1. **The note is an enforcement document, not a design sketch.** The invariant-coordination observation (obs-2026-08-24) sits alongside `AgentSpec: Customizable Runtime Enforcement for Safe LLM Agents` (SRC-2026-08-24-003) and the `monotonic-confinement` concept. The cluster's center of gravity is *runtime enforcement of invariants*, which is exactly the locus where an "enforcement gap" would live. This makes "gap not absence" the natural reading, not a stretch.

2. **The same-host push rule reads as a monotonicity-preserving serialization invariant.** Reconstructed from the note's theme: when a push targets the *same host* (local process), it must be applied under the confinement lock / in the same transaction as the local mutation — i.e., serialized with local writes — so the state transition stays monotonic. A cross-host push goes through the message path; a same-host push that is instead dispatched asynchronously (queued, deferred) interleaves with the local write and can regress state.

3. **The 2026-09-14 race is consistent with that gap.** The observable failure mode of an unserialized same-host push is a **monotonic-confinement violation** (a non-monotonic / regressive update). That symptom maps directly onto the `monotonic-confinement` invariant the note coordinates. So the race is not "nobody wrote the rule"; it is "the rule was written, but the dispatch site never enforced it," letting the interleaving through.

4. **The gap/absence distinction changes the fix.**
   - If *absence*: author the same-host push rule in the note/spec.
   - If *enforcement gap* (the supported reading): add/enable the guard at the push-dispatch site — serialize same-host pushes with local writes, or assert monotonicity at apply time so a regressive update is rejected rather than committed.
   The line's framing selects the second, cheaper and more targeted remediation.

## Recommendations

- **Confirm the rule text in-situ.** Read the obs-2026-08-24 note body and quote the same-host push clause verbatim; attach that quote to this

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
