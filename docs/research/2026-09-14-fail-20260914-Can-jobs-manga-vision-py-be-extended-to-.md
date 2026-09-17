# Can `jobs/manga-vision.py` be extended to output per-beat-class confidence scores, allowing us to detect mislabeled beats automatically during the T1 measurement run?

Status: crystallized 2026-09-14 from research line `fail-20260914-Can-jobs-manga-vision-py-be-extended-to-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260914-Can-jobs-manga-vision-py-be-extended-to-.md.

# Contracted Line: Per-beat-class confidence in `jobs/manga-vision.py` for in-run mislabel detection

**Line:** Can `jobs/manga-vision.py` be extended to output per-beat-class confidence scores, allowing us to detect mislabeled beats automatically during the T1 measurement run?
**State:** expanding → **contracted** (final)
**Model (prior beat):** unsloth:unsloth/Qwen3.8-27B-GGUF · wall 187 s

---

## Grounding note

No filesystem access this turn. Per the grounding rule, only paths named in the line/process are treated as existing anchors: `jobs/manga-vision.py`, `~/Projects/etc/hngh`, `research-lines.tsv`. The prior-art pointer `[[sources/rehearsal-dream-runs-governance-loop-without-mutation]]` is an llm-wiki vault reference (read-only), not a repo file path. Every other module name, class, function, or configuration key below is **inferred from the line's framing** and flagged where it appears.

---

## Findings

### F1 — The extension is structurally straightforward for a discriminative head

If `jobs/manga-vision.py` runs a VLM (vision-language model) that classifies each manga beat into a discrete set of narrative or action classes, the per-class confidence is already present in the forward pass: it is the softmax (or sigmoid, for multi-label) over the final-layer logits. Exposing those scores requires only (a) capturing the raw logits before argmax, (b) serialising them alongside the existing label output, and (c) writing them to a side-channel artefact (e.g. a JSON or CSV column per beat). No architectural change to the model is needed.

*Confidence: high for the general pattern; unverified for this specific job because I cannot read `jobs/manga-vision.py` this turn.*

### F2 — For a generative VLM the mapping is less direct but still tractable

If the job uses an autoregressive VLM (e.g. Qwen-VL, LLaVA, or similar) that emits free-text beat descriptions rather than a fixed-class head, "per-beat-class confidence" must be defined operationally:

- **Token-level logprobs:** sum or mean the log-probabilities of the tokens that constitute each class label in the generated sequence. This is the standard approach (cf. Hugging Face `LogitsProcessor` / `model.generate(..., output_scores=True)`).
- **Sequence-level likelihood:** compute P(label | image) by summing log-probs over the full label string and normalising across candidate classes.
- **Re-ranking pass:** run a second forward pass where each candidate class is prompted as a constrained completion; compare the resulting sequence scores.

The first two options are cheap (one extra tensor capture or one additional generate call per beat). The third is O(|classes|)× more expensive and is only warranted if the label space is small and the T1 run's wall-clock budget allows it.

*Confidence: high for the general pattern; unverified which of these applies to `jobs/manga-vision.py` specifically.*

### F3 — Mislabel detection during the T1 measurement run is a thresholded comparison

Once per-class scores are available, mislabel detection reduces to:

```
for each beat b with label L_b and score vector s_b:
    if argmax(s_b) ≠ L_b  AND  max(s_b) > τ_flip:
        flag b as "high-confidence mislabel"
    elif max(s_b) < τ_low:
        flag b as "low-confidence / ambiguous"
```

Two thresholds serve distinct purposes: `τ_flip` catches cases where the model is *confident* about a different class (likely a genuine label error), while `τ_low` catches cases where the model is uncertain (possibly a genuinely ambiguous beat or a model limitation). Both should be calibrated on a held-out subset of the T1 corpus before the measurement run, not set ad hoc.

*Confidence: high for the logic; unverified for the specific label taxonomy and threshold values used in this project.*

### F4 — The hngh kernel repo is the likely integration surface

The path `~/Projects/etc/hngh` is named as the kernel repository. If `jobs/manga-vision.py` is a job that runs *under* or *alongside* the hngh kernel (i.e. the kernel orchestrates measurement runs and the manga-vision job is one of its workers), then the confidence scores would flow through whatever result-serialisation contract the kernel expects. The exact contract (JSON schema, protobuf, in-memory tensor handoff) is **unverified** this turn; I cannot confirm whether the kernel's result pipeline already has a field for per-class scores or whether a new field must be added.

*Confidence: low — no file-level detail available.*

### F5 — Prior-art pointer does not change the technical answer

The vault reference `[[sources/rehearsal-dream-runs-governance-loop-without-mutation]]` is tagged as governing "rehearsal beats run governance." It is a process/governance document, not a code artefact. It does not alter the feasibility analysis above but may constrain *when* and *how* the extension is deployed (e.g. it must go through a rehearsal beat before touching the T1 measurement run). I cannot read its contents this turn; I flag it as context only.

---

## Recommendations

1. **Add a `--emit-scores` flag (or equivalent) to `jobs/manga-vision.py`.**
   When set, the job captures raw logits (discriminative) or token-level logprobs (generative) and writes them to a side-channel file co-located with the existing label output. The default behaviour (labels only) is unchanged, so the T1 run can be toggled without re-deploying.

2. **Define the score schema before coding.**
   Minimum fields per beat: `beat_id`, `predicted_class`, `true_class` (if known), `score_vector` (dict or list aligned to a fixed class ordering), `top-1 confidence`, `entropy`. This keeps downstream mislabel-detection logic decoupled from the job.

3. **Calibrate thresholds on a held-out slice of the T1 corpus.**
   Before the measurement run, run the scored job on ~50–200 beats with known-correct labels. Plot the score distribution for correct vs. (deliberately) flipped labels; set `τ_flip` and `τ_low` at the intersection or at a chosen F1 operating point. Record the chosen values in the T1 run configuration so they are reproducible.

4. **Gate deployment behind a rehearsal beat.**
   Per the governance pointer, the scored job should be exercised in a rehearsal pass (non-measurement) before it is enabled for the T1 run. This catches schema mismatches, serialisation bugs, and threshold miscalibrations without contaminating measurement data.

5. **Keep the extension additive, not invasive.**
   The change to `jobs/manga-vision.py` should be a thin wrapper around the existing inference call: capture an extra tensor, serialise it, write it out. Avoid refactoring the job's control flow. This minimises regression risk on the measurement run and keeps the diff reviewable.

---

## Open threads

- **O1 — Label taxonomy and cardinality.**
  The specific set of beat classes (narrative beats? action beats? panel-type labels?) is not named in the line or prior material. The cost of the re-ranking option (F2, third bullet) scales with |classes|; if the taxonomy is large (>50), token-level logprob aggregation is strongly preferred. *Unverified; needs a read of `jobs/manga-vision.py` or its config.*

- **O2 — Kernel result-pipeline contract.**
  Whether `~/Projects/etc/hngh` exposes a typed result channel that already accommodates per-class scores, or whether the job must write a separate artefact that the kernel picks up. *Unverified; needs a read of the kernel's job-result interface.*

- **O3 — T1 measurement-run wall-clock budget.**
  The prior beat hit a 187 s wall time on Qwen3.8-27B-GGUF. If the scored run adds a second generate pass (re-ranking), wall time roughly doubles per beat. Whether that fits the T1 budget is an operational question not answerable from this line alone. *Unverified.*

- **O4 — Multi-label vs. single-label.**
  If a manga beat can carry more than one class simultaneously (e.g. "action" + "dialogue"), the score vector is per-class independent sigmoid scores rather than a softmax. The mislabel-detection logic in F3 changes from argmax to a thresholded multi-label comparison. *Unverified; depends on the label schema.*

- **O5 — Governance gate.**
  The rehearsal-beat requirement (F5) means the scored job cannot be enabled for T1 until it has passed at least one rehearsal cycle. The exact governance procedure is in the vault pointer; I cannot read it this turn. *Unverified.*

---

## Verdict

**Yes, `jobs/manga-vision.py` can be extended to output per-beat-class confidence scores.** The change is a thin, additive modification (capture logits/logprobs → serialise → write side-channel). Mislabel detection during the T1 run then reduces to a thresholded comparison between predicted and true class with two calibrated thresholds. The main open risks are operational (wall-clock budget, kernel integration surface) rather than technical.

---

## References

- `jobs/manga-vision.py` — job under extension; named in the research line. *(No filesystem read this turn; all internal structure inferred from the line's framing.)*
- `~/Projects/etc/hngh` — hngh kernel repository; named as integration surface. *(No filesystem read this turn.)*
- `research-lines.tsv` — line-state file for this continuous research process. *(Named in process metadata.)*
- `[[sources/rehearsal-dream-runs-governance-loop-without-mutation]]` — llm-wiki vault pointer (read-only); governs rehearsal-beat deployment. *(Not a repo file path; contents not read this turn.)*

*No external sources are cited. All technical claims (F1–F5) are standard VLM inference patterns; I flag them as inferred-from-general-knowledge rather than verified against this repository's code.*
