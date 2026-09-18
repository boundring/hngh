# patrol: surface manga filed manga-stale on two consecutive runs -- why does it keep failing and which guardrail closes it?

Status: crystallized 2026-09-18 from research line `patrol-20260915-manga-manga-stale`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-patrol-20260915-manga-manga-stale.md.

# Contract: patrol manga-stale non-convergence — Final Structured Summary

**Line:** `patrol: surface manga filed manga-stale on two consecutive runs -- why does it keep failing and which guardrail closes it?`
**Lifecycle:** contracting (final)
**Date:** 2026-09-18

---

## Findings

### F1 — The loop is a fixed point, not a convergence. `[inferred]`

The patrol action "file as `manga-stale`" tags the item but does not remove it from the pool the next run scans. Run N surfaces → files; run N+1 re-surfaces the same item (still in the pool, still matching) → files again. No state transition occurs on file, so the input to each cycle is identical. This diagnosis was carried forward from the expanding beat and remains the working model; it is tagged `[inferred]` because no repository artifact was read in this session that directly demonstrates the absence of a partition move or `last_filed_run` stamp.

### F2 — The designed closing guardrail is the two-consecutive-failure outcome demotion. `[signal]`

The prior-art entry `outcome-demotion-at-two-consecutive-failures` ("Consecutive bad-execution cancellation c…") names the mechanism: two consecutive identical failures should trigger an outcome demotion that cancels or closes the line. The entry title and truncated description support this reading, but the full text was not available in this session; I cannot verify the exact demotion semantics (cancel vs. archive vs. escalate) from the vault pointer alone.

### F3 — A known upstream guardrail-bug class may be blocking the demotion path. `[signal]` `[needs-repo]`

Two prior-art entries point to a bug class in the analytics/live-readme layer where guardrails block or interfere with expected state transitions:

- `obs-2026-08-25-guardrail-bug-filed-upstream-hngh-analytics-live-readme-curr` ("Observati…")
- `pi-llm-wiki-guardrail-blocks-apply-patch-edits` ("pi-llm-wiki guardrail blocked all…")

Both are truncated in the provided material. The hypothesis that this bug class is the *specific* blocker for the manga-stale loop was explicitly tagged `[needs-repo]` in the prior beat and remains unverified. I cannot confirm or deny it without reading the hngh kernel repository at `[redacted path] which I do not have access to in this session.

### F4 — No file-path-level evidence was gathered in this contracting pass.

The expanding beat's diagnosis was built on prior-art signals and inference, not on a direct read of patrol runner source, the surfaceable-set query, or the guardrail dispatch table in the hngh kernel. I am stating this explicitly rather than asserting repository-internal facts I cannot verify.

---

## Recommendations

| # | Recommendation | Confidence / Status |
|---|---|---|
| 1 | **Make filing a state transition.** After `manga-stale` is filed on run N, the item must be excluded from run N+1's surfaceable set (e.g., move to a `filed` partition, or stamp a `last_filed_run` that the patrol query filters on). This breaks the fixed point. | `[inferred]` — design recommendation; no repo artifact confirms current behavior. |
| 2 | **Wire the consecutive-failure demotion to fire on the second identical filing.** The patrol runner should count: if the same item ID + same status tag (`manga-stale`) appears in two consecutive runs, invoke the `outcome-demotion-at-two-consecutive-failures` path. This is the designed close. | `[signal]` — matches prior-art mechanism; exact invocation point unverified. |
| 3 | **Audit the upstream guardrail interaction in the hngh kernel.** Read the analytics/live-readme guardrail layer in `[redacted path] to verify whether the demotion path is intercepted or no-op'd for `manga-stale` filings specifically. The filed observation and the pi-llm-wiki entry point to this layer, but the specific interaction was not confirmed in this session. | `[needs-repo]` — open; requires direct repo access. |
| 4 | **Add a regression test: file `manga-stale` twice on the same item; assert demotion fires on the second filing and the item is absent from the third run's surfaceable set.** Catches both the missing state transition (F1) and the non-firing guardrail (F2/F3). | `[inferred]` — test design; no existing test cited. |

---

## Open Threads

1. **Direct repo read of the patrol runner and surfaceable-set query in `[redacted path] The entire mechanism (F1) is inferred from the observed loop behavior, not from source. A single read of the patrol scan function would confirm or refute the "no state transition on file" model.

2. **Exact demotion semantics of `outcome-demotion-at-two-consecutive-failures`.** The vault entry is truncated to a title fragment. Does it cancel, archive, escalate, or mark-for-review? This determines whether recommendation 2 is correctly specified.

3. **Whether the analytics/live-readme guardrail bug is the specific blocker for manga-stale.** Tagged `[needs-repo]` since the expanding beat. The two prior-art entries establish a *class* of bug but not this instance. Resolving requires reading the guardrail dispatch or patch-apply path in the kernel repo.

4. **Whether `research-lines.tsv` itself records the two consecutive filings as expected.** The line state file is referenced in the process metadata, but its contents for this specific item were not read in this session. Confirming that the TSV shows two identical `manga-stale` entries for the same item ID would close the observational loop.

---

## References

- `research-lines.tsv` — line state file for this research line (referenced in process metadata; contents not read in this session).
- `sources/outcome-demotion-at-two-consecutive-failures` — llm-wiki vault prior-art entry: "Consecutive bad-execution cancellation c…" (truncated pointer; full text not available in this session).
- `sources/obs-2026-08-25-guardrail-bug-filed-upstream-hngh-analytics-live-readme-curr` — llm-wiki vault prior-art entry: "Observati…" (truncated pointer; full text not available in this session).
- `sources/pi-llm-wiki-guardrail-blocks-apply-patch-edits` — llm-wiki vault prior-art entry: "pi-llm-wiki guardrail blocked all…" (truncated pointer; full text not available in this session).
- `[redacted path] — hngh kernel repository. Cited as the location of the patrol runner, surfaceable-set query, and analytics/live-readme guardrail layer per prior material. **No specific file paths within this repository are cited here because none were verified in this session.**
- Prior beat: research beat 2026-09-18 (expanding → contracting), model `unsloth:unsloth/Qwen3.8-27B-GGUF`, wall_s 105.0 — source of the `[inferred]`/`[signal]`/`[needs-repo]` tagging carried into this summary.

---

*Line status: contracted. The diagnosis is as solid as its evidence base allows: the fixed-point mechanism is well-motivated but unconfirmed at source level; the closing guardrail is identified by prior-art signal; the upstream blocker is a known bug class, not yet confirmed for this instance. All three open threads require direct repo access to close.*
