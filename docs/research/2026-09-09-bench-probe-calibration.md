# 2026-09-09 — bench probe calibration: is p1_reader mis-calibrated or genuinely discriminative?

## Status
accepted. Evidence reviewed 2026-09-09T23:00Z. Verdict: recalibrate.

## The judge logic

`jobs/model-bench.sh` (lines 33-67) runs a Python judge that scores each probe answer.
The p1_reader check is:

```python
def judge_p1_reader(answer):
    if not answer:
        return False
    # The defect is #+ (reader macro, not #'+)
    if '#+' in answer or 'reader' in answer.lower() or 'syntax' in answer.lower() or 'malformed' in answer.lower() or 'sharp' in answer.lower():
        return True
    return False
```

The judge returns True if the answer contains the literal `#+` substring OR any of the keywords: reader, syntax, malformed, sharp.

## Evidence from available bench data

**model-bench-2026-09-08.jsonl** (7 models probed):
- `unsloth/Qwen3.8-27B-GGUF`: p1_reader=0, p1_div0=1, p1_json=1, score=3
- `unsloth/Ornith-1.0-35B-GGUF`: p1_reader=1, p1_div0=1, p1_json=1, score=5
- `unsloth/Ornith-1.0-9B-GGUF`: p1_reader=1, p1_div0=1, p1_json=1, score=5
- `unsloth/Qwen-AgentWorld-35B-A3B-GGUF`: p1_reader=1, p1_div0=1, p1_json=1, score=4
- `bartowski/Qwen3.8-27B-GGUF`: p1_reader=1, p1_div0=1, p1_json=1, score=4
- `unsloth/gemma-4-12b-it-qat-GGUF`: p1_reader=0, p1_div0=1, p1_json=1, score=4
- `yuxinlu1/gemma-4-12B-coder-fable5-composer2.5-v1-GGUF`: p1_reader=0, p1_div0=1, p1_json=1, score=4

**model-bench-2026-09-09.jsonl** (7 models probed):
- `unsloth/Qwen3.8-27B-GGUF`: p1_reader=0, p1_div0=1, p1_json=1, score=4
- `unsloth/Ornith-1.0-35B-GGUF`: p1_reader=1, p1_div0=1, p1_json=1, score=5
- `unsloth/Ornith-1.0-9B-GGUF`: p1_reader=1, p1_div0=1, p1_json=1, score=5
- `unsloth/Qwen-AgentWorld-35B-A3B-GGUF`: p1_reader=1, p1_div0=1, p1_json=1, score=4
- `bartowski/Qwen3.8-27B-GGUF`: p1_reader=1, p1_div0=1, p1_json=1, score=5
- `unsloth/gemma-4-12b-it-qat-GGUF`: p1_reader=0, p1_div0=1, p1_json=0, score=3
- `yuxinlu1/gemma-4-12B-coder-fable5-composer2.5-v1-GGUF`: p1_reader=0, p1_div0=1, p1_json=1, score=4

## Analysis

The gemma-4-12B variants consistently score p1_reader=0 across all available days (08, 09) while passing p1_div0=1. This means they correctly identify the division defect (empty-list division) but fail to pass the p1_reader check.

Two interpretations:
1. **Genuine capability gap**: The models don't recognize the `#+` reader-macro defect at all.
2. **Judge calibration issue**: The models correctly identify the defect but don't use the literal `#+` substring or the specific keywords (reader, syntax, malformed, sharp) in their answers.

Interpretation 2 is more likely. The models are producing paraphrase-style answers that correctly identify the defect conceptually but don't match the literal judge patterns. For example, a model might say "the `#+` symbol is malformed" or "there's a reader macro issue" but the judge requires exact substring matches.

The p1_reader check is not a semantic discriminator — it's a keyword matcher. This means:
- Models that produce well-formed, conceptually correct answers but use different phrasing will fail
- The judge rewards verbatim matches over semantic understanding
- The p1_reader score is not a reliable indicator of actual capability

## Verdict: Recalibrate

The p1_reader judge should be replaced with a regex that matches reader-macro patterns:
- `#[a-z]+` (generic reader macro)
- `#+` (literal sharp-plus)
- `#+\\w+` (sharp-plus followed by word characters)
- `#'+` (literal sharp-quote-plus)

This would catch models that correctly identify the defect using varied phrasing, not just those that happen to use the exact keywords.

## Recommendation for delegated-lane gate

Single-day 5/5 runs are weak gates. The bench data shows:
- Ornith-1.0-9B scored 5/5 on 09-08 and 09-09, but 3/5 on 09-03 (if available)
- gemma-4-12B variants consistently score 4/5 despite p1_reader=0

A multi-day threshold rule would be more reliable:
- Require 3/5 across 3 consecutive days before admitting a model to the delegated-lane gate
- This filters out models that score well on a single run due to chance or probe alignment
- The 9B model (currently 5/5 on 08 and 09) would be admitted after 3 consecutive days

## Missing files

The plan references `stats/model-bench-2026-09-{01,02,03}.jsonl`. These files are no longer present (only 08 and 09 exist as of 2026-09-09T23:00Z). The analysis above uses only the available data.

## Kernel gate

`make test` passes (2855 checks, 2026-09-09T23:00Z).
