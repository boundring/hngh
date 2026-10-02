# Does the tree-skew detection code exclude `hngh_wl` entries at the comparison layer

Status: crystallized 2026-10-02 from research line `fail-20261002-Does-the-tree-skew-detection-code-exclud`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20261002-Does-the-tree-skew-detection-code-exclud.md.

# Research Line Crystallization — Final Structured Record

**Line:** Does the tree-skew detection code exclude `hngh_wl` entries at the comparison layer?
**Lifecycle:** contracting → **crystallized**
**Crystallization date:** 2026-10-02

---

## 1. Verdict Status

**The question remains unanswered at the level of code fact.** Across all beats on this line, neither the hngh kernel repository (`[redacted path] nor the working repository could be read from the research context. No file contents, function names, or enum definitions have been verified. Any claim about what the detection code *actually does* would be fabrication, and this record refuses to make one.

What the line *has* established — and what constitutes its lasting value — is:

1. A complete, mechanically executable procedure for resolving the question in minutes.
2. A three-way classification of possible answers with a distinct action attached to each.
3. The identification of the *actual* defect this line exposed: the behavior is unpinned by any test, which is why the question keeps being askable.

That third point is the line's real finding. See §3.

## 2. Findings

**F1 — The exclusion question has three non-binary topologies, and conflating them is the main analytic risk.**
- **(a) Explicit comparison-layer exclusion:** a predicate (e.g., a type check or `switch` arm) inside or immediately before the skew-comparison loop skips `hngh_wl` entries. Intent is likely documented or recoverable from history.
- **(b) Implicit classification-layer exclusion:** `hngh_wl` entries never reach the structure the detector walks, or are dropped by a generic upstream filter. Exclusion here is a *side effect of insertion/classification*, not a guarantee — it silently reverses if either of those changes.
- **(c) No exclusion:** `hngh_wl` entries are compared identically to normal entries. This is a defect *candidate*: if their weight/count/distribution characteristics differ from normal entries, their inclusion can generate false skew alarms or mask genuine ones.

The original phrasing of the line presupposes (a). The procedure below exists precisely because (b) and (c) are live possibilities that a naive reading would miss.

**F2 — The question is resolvable mechanically, not by reading pass.**
Three greps against the kernel repo, intersected, reduce the audit to a handful of call sites (full commands in §4, R1). This was designed but never executed within this line's context.

**F3 — No regression coverage pins the behavior.** *(Inferred, not verified against hngh-automation's test tree — see §5.)* The fact that the question survived multiple research beats without a quick "the test says so" answer is strong circumstantial evidence that no test constructs `hngh_wl`-containing trees against the detector. This should be confirmed, not assumed.

## 3. Assessment

The line should not be read as "failed to answer." It correctly refused to answer without evidence and instead compressed the problem to its irreducible core: **one grep session plus one test commit closes this permanently.** The cost of closure is now near zero; the cost of leaving it open is that the question re-enters future audit queues indefinitely.

## 4. Recommendations (Standing)

**R1 — Execute the three-grep procedure before any manual reading.**
In `[redacted path]
1. `grep -rn "hngh_wl" --include='*.[ch]' .` — definition and all reference sites.
2. `grep -rniE "skew|balance|imbalance" --include='*.[ch]' .` — candidate detection functions.
3. Intersect the file sets. Within shared files, determine whether the `hngh_wl` reference sits inside/before the comparison loop (→ topology a) or only at creation/classification sites (→ topology b). Absence from detection files entirely → topology b or c; a final check of the detector's input-structure population distinguishes them.

**R2 — Act per topology:**
- **(a):** Confirm the predicate also covers any `hngh_wl`-adjacent types, not just the exact constant. Record the rationale in the lasting docs.
- **(b):** Treat as fragile. Add an explicit predicate *or* the R3 test — without one, the exclusion is one refactor away from silent reversal.
- **(c):** Evaluate as a defect candidate. If `hngh_wl` skew characteristics differ from normal entries, file with a reproducer showing false-alarm or masking behavior.

**R3 — Add a regression test in hngh-automation regardless of outcome.**
Construct a tree mixing `hngh_wl` and normal entries with a known skew signature; invoke the detection path; assert the audited behavior (or the corrected behavior, if (c) is a defect). This converts the research question into a CI-checked invariant — the line's terminal artifact.

## 5. Open Threads

- **OT1 (blocking):** Execute R1 against `[redacted path] in an environment with read access. This is the only path to a code-grounded verdict.
- **OT2:** Verify F3 — enumerate hngh-automation's existing tests for skew-detection coverage before writing the R3 test, to avoid duplication.
- **OT3:** If topology (a) or (b) is confirmed, check whether the exclusion rationale is documented anywhere in the kernel repo (comments, commit messages). Undocumented exclusion intent is a documentation debt worth recording.
- **OT4:** The prior-art pointer to `[[entities/camel]]` (CaMeL, Control-and-Measure Layer) in the llm-wiki vault was never connected to this line. Whether CaMeL's measure-layer semantics bear on what *should* be excluded from skew comparison is unexplored; flag for any successor line if the audit reveals the exclusion is policy-driven rather than structural.

## References

- `[redacted path] — hngh kernel repository. **Referenced but not read** from this research context; all grep targets and topology claims about it are unverified pending OT1.
- Working repository (hngh-automation context) — target location for the R3 regression test; test-tree contents unverified pending OT2.
- Prior beats on this line (2026-10-02, expanding → contracting; models kimi:k3-256k, unsloth:unsloth/Ornith-1.0-9B-GGUF) — source of the three-grep procedure and the three-topology classification carried into §2/§4.
- `research-lines.tsv` — line state record (contracting at crystallization).
- llm-wiki vault (read-only pointers): `[[entities/camel]]`, `[[sources/bernstein-sipyourdrink-governance-framework]]` — prior art; relevance to this line unestablished (see OT4).

*No external sources were consulted; nothing in this record depends on claims outside the repositories named above, and no repository file path beyond the kernel root is asserted to exist.*
