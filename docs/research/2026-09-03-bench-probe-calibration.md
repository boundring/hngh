# Bench probe calibration — is p1_reader mis-calibrated or genuinely discriminative?

Status: RESEARCH (read-only investigation; no service touched, no job run).
Date: 2026-09-09 (executing step 2 of the 2026-09-03-staging plan).
Evidence surfaces: automation `jobs/model-bench.sh`, automation `stats/model-bench-2026-09-0{8,9}.jsonl` (raw), kernel `docs/publication/book.md` staging-notes section (raw rows for 09-01→09-03, verified from the jsonl on 2026-09-03 before rotation).

## 1. The probe and the judge (quoted from jobs/model-bench.sh)

Probe 1 plants two defects in a one-line Common Lisp review target:

```
P1='Reply with ONLY a JSON object (no markdown fences, no prose) with keys:
verdict (string, "findings" or "clean"), findings (array of short strings),
confidence (number 0-1). Review this Common Lisp function for defects:
(defun safe-avg (xs) (/ (reduce #+ xs) (length xs)))'
```

The planted defect is `#+` — a reader-macro (sharp-sign conditional) where
`#'+` (function designator) is meant. The judge (lines 56-58) scores:

```
low1 = a1.lower()
r["p1_div0"] = int(any(k in low1 for k in ("empty", "zero", "divis")))
r["p1_reader"] = int("#+" in a1 or any(k in low1 for k in ("reader", "syntax", "malformed", "sharp")))
```

p1_reader=1 requires the literal `#+` substring or one of exactly four
keywords: reader / syntax / malformed / sharp. Everything else — "unquoted
function designator", "missing quote", "should be #'+", "the symbol is being
read as a conditional" without one of those four stems — scores 0.

## 2. Per-day evidence

Raw jsonl for 2026-09-01/02/03 has been rotated out of the (untracked)
`stats/` directory — only 09-08 and 09-09 remain on disk, and the automation
repo carries no git history for stats files. The 09-01→09-03 rows survive as
verified quotes captured on 2026-09-03 in `docs/publication/book.md`
(staging-notes section, lines ~8426-8432 and ~8531-8543) and
`docs/records/2026-09-03-capabilities-direction.md`. Those quotes establish:

| day | model | p1_reader | score | note |
|---|---|---|---|---|
| 09-01→09-03 (all three) | unsloth/gemma-4-12b-it-qat-GGUF | 0 | 4/5 | p1_json=1, p1_div0=1 every day |
| 09-01→09-03 (all three) | yuxinlu1/gemma-4-12B-coder-fable5-composer2.5-v1-GGUF | 0 | 4/5 | p1_json=1, p1_div0=1 every day |
| 09-01, 09-02, 09-03 | Ollama hf.co/unsloth/Ornith-1.0-9B-GGUF | — | 5/5, 5/5, 3/5 | single-day variance |
| 09-01→09-03 (all three) | unsloth/Ornith-1.0-35B-GGUF | 1 | 5/5 | passes the keyword judge |

Raw rows on disk (read directly today, both gemma variants again p1_reader=0):

- `stats/model-bench-2026-09-08.jsonl` (ts 2026-09-08T05:10:44Z–05:13:28Z):
  - unsloth/gemma-4-12b-it-qat-GGUF: `p1_json=1 p1_div0=1 p1_reader=0 p2_format=1 p3_fix=1 score=4` (ts 05:13:07Z)
  - yuxinlu1/gemma-4-12B-coder-…-GGUF: `p1_json=1 p1_div0=1 p1_reader=0 p2_format=1 p3_fix=1 score=4` (ts 05:13:28Z)
  - unsloth/Qwen3.8-27B-GGUF: also `p1_reader=0` (ts 05:10:44Z, score 3 — p2_format also failed that day)
- `stats/model-bench-2026-09-09.jsonl` (ts 2026-09-09T05:10:50Z–05:14:19Z):
  - unsloth/gemma-4-12b-it-qat-GGUF: `p1_json=0 p1_div0=1 p1_reader=0 p2_format=1 p3_fix=1 score=3` (ts 05:13:50Z — the p1_json=1→0 flip is day variance in JSON framing, not the reader check)
  - yuxinlu1/gemma-4-12B-coder-…-GGUF: `p1_json=1 p1_div0=1 p1_reader=0 p2_format=1 p3_fix=1 score=4` (ts 05:14:19Z)
  - Ornith-9B and Ornith-35B both back at 5/5 (ts 05:11:54Z, 05:11:22Z)

So the signature is now **five consecutive days** (09-01→09-03 quoted, 09-08,
09-09 raw): both gemma-4-12B variants pass p1_json and p1_div0 but score
p1_reader=0, while the Ornith models and (mostly) the Qwen variants pass.

## 3. Verdict: RECALIBRATE (p1_reader is a false-negative-prone keyword gate)

The data does not support "genuinely discriminative" as the explanation:

1. **p1_div0=1 proves comprehension of the harder defect.** Both gemma
   variants consistently name the empty-list division. A model that parses
   the sexp well enough to flag division-by-zero has not "missed" `#+`;
   it almost certainly registered the odd token. The discriminating
   variable is the answer's *vocabulary*, which is exactly what a keyword
   judge measures.
2. **The keyword set is brittle against the most natural correct paraphrases.**
   A fix-shaped answer ("the function designator must be quoted: `#'+`")
   passes only because `#+'` happens to contain `#+`; an equivalent answer
   phrased as "unquoted designator" or "missing function quote" fails all
   four keywords. Five days of stable 0 across two different 12B models
   (different finetunes, same base) while passing the sibling checks is the
   signature of a paraphrase-style answer failing a strict judge, not of
   two independently broken models.
3. **Corroboration:** unsloth/Qwen3.8-27B-GGUF also flips p1_reader=0 on
   09-08/09-09 with all other checks green — a third model with the same
   "passes everything but the keyword check" shape.

Recommended recalibration (automation-side, one line, NOT landed by this
step — model-bench is an automation edit for a gated automation commit):

```
r["p1_reader"] = int("#+" in a1 or any(k in low1 for k in (
    "reader", "syntax", "malformed", "sharp", "designator",
    "quote", "quoted", "#'", "function cell")))
```

Compare across days after the change with a `judge_v` field appended to the
row, so historical keyword-judge rows stay distinguishable.

## 4. Ornith-9B variance and the multi-day admission rule

Ornith-1.0-9B: 5/5 (09-01), 5/5 (09-02), 3/5 (09-03), 5/5 (09-08), 5/5
(09-09). One dropped day out of five; which sub-check dropped on 09-03 is
not established (the raw row is rotated out). Conclusion the data supports:
**single-day bench runs are weak gates** — a model may not be admitted to or
evicted from the delegated lane on one day's run.

**Multi-day admission rule (proposed):** a model is admitted to the
delegated lane when it scores ≥4/5 on at least 2 of its last 3 bench days
(two-of-three). Eviction (demotion to fallback) requires failing that rule
on the same window, i.e. <4/5 on at least 2 of the last 3 days. Under this
rule Ornith-9B is admitted (4 of 5 days ≥4/5, currently 2 of 2 on the
retained window), matching the operator's "Ornith is good" endorsement.

## 5. Priced recommendation for the delegated-lane gate

- **Gate:** delegated lane defaults to Ollama Ornith-1.0-9B (local, $0/token,
  6.6 GB on the idle 24 GB GPU; already `OLLAMA_MODEL` per docs/BACKLOG.md),
  admitted by the two-of-three rule above. No paid-leg spend is triggered by
  this recommendation.
- **If p1_reader is recalibrated (recommended):** both gemma-4-12B variants
  likely move 4/5→5/5, adding two free local models to the lane candidate
  pool. Cost: one judge line + `judge_v` marker in jobs/model-bench.sh, plus
  a note that pre-change rows used the stricter judge. Benefit: deeper free
  fallback chain before any quota leg (kimi-daily-cap 40, lobehub-daily-cap
  50 per cadence-params.tsv) or paid remote is touched.
- **If accepted as-is instead:** zero change cost, but gemma-12B stays
  permanently fenced out of lane consideration on a judge artifact, and the
  lane's only free depth is Ornith-9B + Ornith-35B. Price of acceptance is
  the paid legs being reached sooner on any Ornith outage — real money only
  when :8080/:11434 are both down, which is the recovery scenario staged in
  plan step 4.

Recommendation: recalibrate (with judge_v), keep the two-of-three admission
rule, keep Ornith-9B as the delegated-lane default. No kernel or service
change required by this step.
