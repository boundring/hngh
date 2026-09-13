# Why does cadence/hour/33-research-beat.sh show wall=28.3s against a 0.1s median (x9, later 387.1s vs 174.6s median), is that latency a defect or expected model-leg work, and what disposition (fix or park) does the beat design support?

Status: crystallized 2026-09-13 from research line `fail-20260909-slow-unit-dropin-33-research-beat.sh`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260909-slow-unit-dropin-33-research-beat.sh.md.

# Research Line Crystallization — Cadence Beat Latency

**Line:** Why does `cadence/hour/33-research-beat.sh` show wall=28.3s against a 0.1s median (x9, later 387.1s vs 174.6s median), is that latency a defect or expected model-leg work, and what disposition (fix or park) does the beat design support?
**Lifecycle state:** contracting → **crystallized** (this document is the lasting record)
**Model (prior beat):** deck:deck-7b | wall_s: 56.0

---

## Findings

### F1. The two metrics measure different scopes of work
The "0.1s median" and the "wall=28.3s" figure are not contradictory measurements of the same operation. The sub-second figure is consistent with the *local, mechanical* portion of a beat: reading `research-lines.tsv`, selecting a line, and appending state. The 28.3s wall figure is consistent with the *model leg*: prompt construction, an inference call, and streaming a completion back into the line's record. Nothing in the observed data requires an I/O defect to explain the gap — the gap is the model call. (This is an inference from the magnitudes; the exact instrumentation point where `wall_s` is measured inside `cadence/hour/33-research-beat.sh` was not confirmed by reading the script source in this line's lifetime, and remains an open verification item.)

### F2. The 387.1s / 174.6s median pair signals an unguarded model leg
The later observation — wall=387.1s against a 174.6s median — shows the *median itself drifting upward* alongside tail spikes. A healthy beat with a fixed-size prompt would show a stable median with occasional cold-start outliers. A rising median plus a heavy tail is consistent with some combination of: (a) growing prompt size as the line's prior material accumulates (more tokens in, more tokens out), (b) retries on inference failure, or (c) queuing/contention on the model endpoint. Absent a timeout or token-budget guard in the beat, all three are unbounded. This line cannot confirm which of (a)–(c) dominates without reading the script and its logs; see Open Threads.

### F3. This line's own prior beat reproduced the failure mode
The prior material on this line was **truncated at the model call** — the completion hit the max_tokens cap (`finish_reason=length`) mid-sentence ("...reflects the true end-to"). This is direct, in-line evidence that the beat's model leg lacks an output-budget discipline: the beat ran long, produced a large completion, and still did not finish. The latency question and the truncation are the same defect viewed from two angles — the model leg is unbounded in both time and tokens.

### F4. Design context: the kernel's own sources counsel async long gates
The vault pointer `[[sources/long-gates-run-async-against-interjections]]` (llm-wiki, prior art) states the principle that long verification gates should run asynchronously so interjections are not blocked. A cadence beat whose synchronous model leg can occupy 28–387s is exactly the pattern that source warns against: the host is held for the duration of a network/inference-bound call instead of dispatching it and staying in motion.

---

## Interpretation: defect or expected work?

**Both, in layers.** The 28.3s median is *expected model-leg work* — an LLM call at that magnitude is normal and not a bug. The *defect* is architectural, not numerical: the beat performs that work **synchronously, without timeout, retry, or token-budget guards**, inside a cadence loop whose purpose is to keep the research line continuously in motion on idle hosts. Expected work executed in an unguarded blocking position is a defect of disposition, not of the model.

## Disposition recommendation: **Fix — refactor, do not park**

Parking is not supported: the beat is the mechanism by which this research line (and presumably others) advances, and the failure mode is already manifesting (truncated beats, drifting medians). The concrete fix, in order of leverage:

1. **Bound the model leg.** Add a wall-clock timeout and a max_tokens budget sized to the beat's output contract (a structured line entry, not an essay). The truncation of this line's prior beat shows the current prompt invites unbounded output.
2. **Bound the input.** Cap or summarize the "prior material" fed to the model. The rising median (174.6s) is consistent with prompt growth; a rolling digest would stabilize it.
3. **Decouple mechanics from inference.** Let the beat's TSV state mutation (the genuinely sub-second part) complete and mark the line as "beat dispatched," with the model leg writing back asynchronously — the pattern endorsed by `[[sources/long-gates-run-async-against-interjections]]`.
4. **Instrument the split.** Log `wall_local_s` and `wall_model_s` separately so the next recurrence of this question is answerable from the log rather than from inference about magnitudes.

If implementation capacity is scarce, item 1 alone converts the failure from "silent 387s block plus truncated output" to "bounded, legible failure," which is the minimum viable fix.

---

## Open threads

- **OT1 (verification):** Read `cadence/hour/33-research-beat.sh` in the hngh kernel (`/home/bricker/Projects/etc/hngh`) to confirm where `wall_s` is measured, whether any timeout/retry logic already exists, and how the prompt is assembled. All findings above about script internals are inferred, not read.
- **OT2 (attribution):** Decompose the 387.1s tail — retries vs. prompt growth vs. endpoint contention — using the split instrumentation from recommendation 4.
- **OT3 (fleet check):** Determine whether other scripts under `cadence/hour/` share the same unguarded model-leg pattern; if so, the fix should land as a shared wrapper, not a one-off edit.
- **OT4 (metric provenance):** Establish where the "0.1s median" claim originated — legacy instrumentation of a pre-model beat, or a mislabeled log field — so future line entries compare like with like.

## Caveats

- I could not read the filesystem during this crystallization. Paths cited below are those named in the research line itself, its prior material, or the task prompt; their *contents* were not directly inspected in this session. Claims about script behavior are inferences from observed timings and the truncated prior beat, flagged as such above.
- The vault pointers (`[[sources/...]]`) are prior-art references from the llm-wiki vault; their full text was not re-read here beyond what the prior material quoted.
- No external sources were used; none are asserted.

---

## References

- `cadence/hour/33-research-beat.sh` — the beat under study (hngh kernel repository, `/home/bricker/Projects/etc/hngh`; path named in the research line).
- `research-lines.tsv` — line state ledger (path named in the task prompt).
- `/home/bricker/Projects/etc/hngh` — hngh kernel repository root (named in the task prompt).
- `[[sources/long-gates-run-async-against-interjections]]` — llm-wiki vault, prior-art pointer: run long verification gates async so interjections are not blocked.
- `[[sources/debug-repro-sandboxes-only]]` — llm-wiki vault, prior-art pointer (listed in prior material; not directly load-bearing for the findings).
- Prior beat on this line (2026-09-13, deck:deck-7b, wall_s 56.0) — truncated at max_tokens cap; cited as evidence for F3.

**Line state:** crystallized. Disposition on record: **fix (bound and async the model leg); park rejected.** Open threads OT1–OT4 stand for any future beat that picks up verification work.
