# Does the beat script's state model distinguish between "timeout-complete" and "in-progress" markers, and if not, what is the minimal patch to close this gap?

Status: crystallized 2026-09-15 from research line `fail-20260915-Does-the-beat-script-s-state-model-disti`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260915-Does-the-beat-script-s-state-model-disti.md.

# research beat 2026-09-15 (contraction — final)

_line: Does the beat script's state model distinguish between "timeout-complete" and "in-progress" markers, and if not, what is the minimal patch to close this gap? | state: contracted → crystallized | prior beats: same line, 2026-09-15 (expanding), 2026-09-15 (contraction)_

## Access disclaimer (binding, unchanged)

I have no filesystem or tool access to `~/Projects/etc/hngh` or to the working repository containing `research-lines.tsv`. I have never read the beat script in this session. Therefore **no claim below asserts that a specific file, symbol, enum member, or line exists** in the beat script. The only paths stated with confidence are the two the task itself names: `research-lines.tsv` (this line's state file) and `~/Projects/etc/hngh` (the hngh kernel repository). Every concrete recommendation is a *conditional* instruction gated on a verification step; if verification contradicts it, verification wins. Where I would normally reach for an external source to confirm behavior, I say so explicitly rather than assert it.

## Findings

**F1 — The question resolves at the representation layer, and the answer is one of two shapes.**
Completion in the beat script's state model is either (a) *stored* — a token written at finalization time — or (b) *derived* — computed from timestamps at read time. These are mutually exclusive at the writer site: a single finalization path cannot both emit a completion token and leave completion to be inferred from `now >= deadline`. The prior beat's reasoning holds that the gap ("timeout-complete" collapsing into either clean-complete or in-progress) has a *different* minimal patch under each shape. This is the load-bearing finding: **the correct patch is not knowable until the representation is classified.** I cannot classify it here because I have not read the script; the classification step (R1 below) is therefore part of the lasting record, not an optional preamble.

**F2 — "timeout-complete" must be terminal-but-distinguished, not nominal.**
Whatever closes the gap must not make a timed-out completion indistinguishable from a clean one. The prior beat flagged that downstream behavior branches on this distinction: retry, reconciliation, and attestation (per the hngh ceremony-loop pattern). If the patch makes `timeout_complete` read as plain `complete`, it silently converts a "needs attention" terminal state into a "no action" terminal state — a correctness regression, not a cosmetic one. Conversely, if the patch leaves timeout completion in the *in-progress* bucket, it is worse: a finished beat is treated as still running, which can stall reconciliation or trigger spurious liveness checks. The distinction is load-bearing on both sides of the collapse.

**F3 — A new state token is a vocabulary change, and closed vocabularies constrain where it may be introduced.**
The prior art pointer `[[sources/hngh-ceremony-loop-mechanics]]` (closed vocabularies) is the governing constraint here: in a closed-vocabulary system, adding a state token is not a local edit. It must be added at exactly one definition site and consumed by every reader that branches on completion. The failure mode to avoid is smuggling the token in as a string literal at one call site while readers still match on the old vocabulary — which produces a state that some readers see and others do not, i.e., a *partial* state transition. I am citing this pointer from the prior-art list; I have not independently verified its contents beyond what the prior beat recorded, so treat "closed vocabularies" as the prior beat's characterization of that source, not as something I re-derived.

**F4 — The minimal patch is small *only if* readers branch on the vocabulary, not on string literals.**
The prior beat's R2/R3 sizing ("small: definition + one writer branch + reader branches") is conditional. If a reader pattern-matches on the literal string `"complete"` rather than on an enum/symbol reference, then adding `timeout_complete` does not automatically reach that reader — and the diff grows as each such site is found and fixed. The honest statement of minimality is: *the patch is minimal in the stored case when the vocabulary is referenced symbolically end-to-end; it is not minimal (and may be unsafe) when readers string-match.* I cannot verify which holds for this script without reading it.

## Recommendations

These are the line's lasting, actionable record. Each is gated on verification; none is an assertion about current file contents.

**R1 — Classify the representation before writing any code (one probe pass, zero code).**
From the repository root, run probes such as:
- `grep -rn "timeout" --include='*beat*' .` and `grep -rn "in.progress\|in_progress" .`
- `grep -rn "deadline\|completed_at\|finished_at" .`

Then classify against F1:
- A **writer** emitting a completion token (an enum member, a status string, a marker file) → model is *stored* → proceed to R2.
- Only **readers** computing completion from timestamp comparisons (`now >= deadline`, `completed_at is not None`) with no writer-side token → model is *derived* → proceed to R3.

This step is non-negotiable: it selects the patch shape and prevents applying the wrong minimal fix.

**R2 — Minimal patch, stored case (one token, one writer branch, one reader audit).**
1. Add a third state token at the single definition site (e.g., `timeout_complete` alongside `in_progress` / `complete`). Do **not** reuse a boolean or overload `complete`.
2. In the finalization path that fires at the deadline boundary, write `timeout_complete` instead of `complete`. The clean-finish path is untouched.
3. Audit every reader that branches on completion. Safe default migration rule: any reader that previously treated `complete` as "terminal, no action" should treat `timeout_complete` as "terminal, needs reconciliation/retry" — matching the retry/attestation semantics in F2. Readers that only ask "is it terminal?" should match on both tokens.
4. If the diff grows beyond definition + one writer branch + reader branches, that is evidence readers were pattern-matching on the string rather than the vocabulary (F4). Fix the string-matching sites instead of widening the token; do not paper over it by adding more tokens.

**R3 — Minimal patch, derived case (no new token; make the derivation three-valued).**
If completion is derived from timestamps and there is no writer-side token to extend:
1. Introduce a *derived* predicate that returns three values (`in_progress`, `complete`, `timeout_complete`) rather than two. The boundary condition is typically `now < deadline` → in-progress; `completed_at` present and `completed_at <= deadline` → complete; `now >= deadline` with no clean completion → timeout-complete.
2. Because the model is derived, there is no single writer branch to edit — instead, every *read site* that currently computes a boolean "is it done?" must be updated to consume the three-valued predicate. This is where the stored/derived asymmetry bites: the derived case's patch surface is the set of readers, not a writer.
3. Preserve F2: the three-valued result must keep timeout-complete terminal-but-distinguished at every read site, with the same retry/reconciliation default as R2.3.

**R4 — Verification gate for both cases (applies after R2 or R3).**
After patching, confirm closed-vocabulary integrity per F3: grep for the old token's literal form and confirm no reader still matches it in a way that would now misclassify `timeout_complete`. Confirm the clean-finish path is byte-for-byte untouched. If any external documentation of the state model exists (a README, a schema file, a ceremony doc), update it in the same change so the vocabulary's definition site and its documentation do not drift — I cannot verify whether such documentation exists in this repository, so treat this as conditional on finding it.

## Open threads

1. **The representation is unclassified.** F1 is the load-bearing unknown and I have no access to resolve it. The line's lasting value is that it forces R1 before any patch; a future beat with read access should open by running R1 and recording stored-vs-derived, then close out R2 or R3.
2. **Whether readers branch symbolically or by string literal (F4) is unverified.** This determines whether the patch is genuinely minimal or quietly large. A verification pass over reader sites would settle it; I cannot do so here.
3. **The exact deadline-boundary semantics are unspecified in this line.** The prior beats assume a single deadline boundary fires timeout completion, but they do not pin down what happens at exactly `now == deadline` (inclusive vs. exclusive) or whether a beat that finishes *at* the deadline is clean-complete or timeout-complete. That edge case is a real ambiguity worth one more probe; I flag it rather than assert a resolution.
4. **Interaction with attestation/reconciliation is asserted, not verified.** F2 and R2.3 rely on the prior beat's claim (via `[[sources/hngh-ceremony-loop-mechanics]]`) that downstream retry/attestation branches on the complete-vs-timeout distinction. I have not independently confirmed that branch exists in this repository; if it does not, the "must be distinguished" requirement weakens to a bookkeeping preference rather than a correctness invariant.

## References

- `research-lines.tsv` — this line's state file (named by the task; no contents asserted).
- `~/Projects/etc/hngh` — hngh kernel repository (named by the task; no file contents asserted).
- `[[sources/hngh-ceremony-loop-mechanics]]` — prior-art pointer cited for "closed vocabularies"; characterized as such by the prior beat, not independently re-verified this session.
- Prior beats on this line, 2026-09-15 (expanding) and 2026-09-15 (contraction) — source of F1–F4 reasoning and R1–R3 structure.

No external sources were used; every claim above is either grounded in the two task-named paths, in prior beats on this line, or explicitly marked as unverified/conditional.
