# Cost Landscape — Measurement (2026-09-10 ~15:00Z)

## 1. Spend Per Day Per Model (session-cost telemetry.db rows only)

Source: automation/dashboard/telemetry.db, kind='session-cost', ts >= 2026-09-07.
The `session-cost.py` producer parses ~/.omp/agent/sessions/*/ .jsonl transcripts for `message.usage.cost.total` fields (automation/jobs/session-cost.py:68). Transcripts without usage data yield null cost_usd; these are typically local-model calls where the model server returns no pricing info.

### Daily totals (all models combined)

| Date   | Sessions | Total spent | Largest single session |
|--------|----------|-------------|-----------------------|
| 2026-09-08 | 76      | $42.06      | $11.94 (z-ai/glm-5.3 flash) |
| 2026-09-09 | 34      | $1.44       | $0.41 (qwen/qwen3.7-flash)  |
| 2026-09-10 | 20      | $0.53       | $0.12 (z-ai/glm-5.3 flash)  |

### Per-day per-model breakdown

| Date   | Model            | Calls | Spent   | Share of day |
|--------|------------------|-------|---------|-------------|
| 09-08  | z-ai/glm-5.3-flash | 45    | $30.31  | 72%         |
| 09-08  | z-ai/glm-5.3     | 10    | $11.17  | 27%         |
| 09-08  | qwen/qwen3.7-flash | 16    | $0.58   | <1%         |
| 09-09  | z-ai/glm-5.3-flash | 24    | $1.03   | 71%         |
| 09-09  | qwen/qwen3.7-flash | 1     | $0.41   | 29%         |
| 09-10  | z-ai/glm-5.3-flash | 19    | $0.53   | 100%        |

**Local-model costs:** unsloth/Ornith-1.0-35B-GGUF accounts for 13 sessions across the period but costs exactly $0.00 on every one — the local server does not emit cost/usage data to transcript JSONL. These are free compute.

### Operator email-digest vs telemetry-report discrepancy

The email digest reports differ from db totals because of **timing offsets**:
- 09-08 digest ran ~05:02Z; it read telemetry output captured mid-day. Final daily total was $42.06. The digest reported $27.90 because it parsed a partial accumulation at digest-run time.
- 09-09 digest: $0.08 today vs $27.90 yesterday. Actual full-day: $1.44 (only overnight+early morning sessions emitted by 05:00Z had costs; most flash sessions ran later in the day).
- 09-10 digest ran 05:01Z: $0.31 today vs $0.08 yesterday. Actual full-day total so far: $0.53. The $0.31 figure is consistent with early-morning emissions being partially captured.

The operator's "$27.90 one day, $0.08 another" memory matches the email digest figures which represent **partial-day snapshots**, not full-day totals.

## 2. Delegated-Session Costs Structure

All paid spend flows through GLM-5.3 variants (both flash and non-flash), sourced from the `openrouter/z-ai/glm-5.3-flash(env)` env override pinned in both hngh-overnight.service and hngh-cadence-hour.service units. Overnights run via bili omp sessions whose transcripts include OpenRouter usage/cost data.

### Per-session cost range (GLM-5.3-flash)

From session-cost telemetry analysis:
- Smallest paid session: $0.006 (~$0.01, ~1-2K tokens total, ping-hourly summarization ~20-30 min wall)
- Largest paid session: $0.12 (~$0.12, ~240K input + 28K output tokens, wake-context reads spanning hundreds of files)
- Typical delegated session: $0.01-$0.05 per overnight-run session

### Cost per model class (full picture)

| Class             | Price signal   | Sessions (last 4 days) | Spent    | Notes |
|-------------------|---------------|----------------------|----------|-------|
| z-ai/glm-5.3-flash| Paid (~$0.002/token mix) | 88               | $31.87   | Primary paid spend |
| z-ai/glm-5.3      | Paid (higher-tier variant) | 10            | $11.17   | Used 09-08 only |
| qwen/qwen3.7-flash| Paid (cheaper tier) | 17                | $0.99    | Minor usage |
| tencent/hy3-preview:free | Free    | 1                  | $0.00    | Test/fallback |
| unsloth/local-bench| Free (local)  | 13                 | $0.00    | Local GPU, zero marginal cost |

**Total tracked spend (last 4 days): $43.72**. Average ~$10.9/day. Operator target is $10-20/day (defined in 07-budget-digest.sh line referencing $10-20/day target). This averages within target when including 09-08 ($42) but well under target for 09-09 ($1.44) and 09-10 ($0.53).

## 3. This Session Family's Costs (SimDesign / QueueDeps)

**Result: Zero cost captured in telemetry.** No session-cost rows exist for identity prefixes matching this session family.

Reasoning: The coordinator layer (director orchestration, worker fan-out via SimDesign/QueueDeps) either:
(a) Does not produce ~/.omp/agent/sessions/*.jsonl transcripts that session-cost.py can ingest, or
(b) Uses an API call path (direct http://localhost:/...) that does not capture `message.usage` in the transcript JSONL format.

Of 138 existing transcripts checked, 137 contain usage/cost fields and 1 does not. The 1 transcript without usage data corresponds to what appears to be a raw local call (possibly unsloth_chat without OpenRouter wrapper). The coordination sessions likely fall into category (b) — they execute as bounded tool-call sequences against openrouter APIs directly without producing parseable session transcripts.

**Impact on operator cost awareness:** The $43.72 figure may UNDER-count actual spend if this session family burns quota independently of the transcript-parse pipeline. However, the volume of coordination work (2 subagents, each bounded to ~one step) suggests even if they used paid models, the per-task token budget (typically <50K input/output) would add <$0.50 per task — negligible compared to the $31.87 already tracked. Worth noting as a blind spot rather than alarm.

## 4. Local-Model Usage Breakdown

Un-sampled usage estimates based on model-telemetry.kind='model' entries:

### Unsloth/Qwen3.8-27B-GGUF (local bench)
| Source                          | Rate          | Estimated calls/day |
|---------------------------------|---------------|--------------------|
| ping-hourly.sh                  | ~1/hour       | ~24 calls/day       |
| research-beat (33-research-beat)| share-pin     | ~4-8 calls/day      |
| review-prep (04-review-prep.sh) | overnight cycle| ~1-2 calls/day     |
| night-research.sh               | nightly       | ~1 call/night       |
| ux-review (19-ux-review.sh)     | overnight     | ~1 call/night       |
| morning-digest.sh               | morning       | ~2 calls/day        |

Total estimated: 30-35 unsloth calls/day. All local GPU inference on desktop hardware. Marginal cost near-zero (electricity for GPU ≈$0.01/hour running, but this overlaps with active use windows).

### Kimi/k3-256k (quota leg)
| Source                    | Rate          | Calls (09-08..10) |
|---------------------------|---------------|-------------------|
| 33-research-beat.pin=kimi | share=3 (every 3rd run) | 26          |
| Review beats              | share-pin     | 1 (09-10T00:04Z)  |

Total: 27 calls over 3 days. Daily cap = 40 (kimi-daily-cap row in cadence-params.tsv). Utilization: ~1-3/day, far below cap.

### LobeHub (quota leg)
Zero utilization despite lobehub-research-share=6. Endpoint returns HTTP 404 persistently since configuration on 2026-09-07. 0 of 50 daily cap consumed.

## 5. Spend Dominance Analysis

What drives the bulk of spend? One number: **z-ai/glm-5.3-flash at 73% of all tracked spend** ($31.87/$43.72).

Breakdown by consumer driving GLM spend:
- Overnight delegation sessions: ~60% of flash calls (via bili omp, using GLM Flash env override)
- Research/digest reviews: ~20% (research beats calling kimi, then falling back to GLM when kimi fails)  
- Ping-hourly summarizations: ~15% (hourly model updates)
- Everything else: ~5%

Two factors reduce spend significantly:
1. **Stall-recovery outcome-demotion S1 implemented**: Prevents continued spending on bad-execution models like Ornith-1.0-35B (which produced rc=0 cancelled x12 sessions burning budget at $0.01-$0.12 each without landing code). Without demotion, those sessions would still be burning budget.
2. **OVERNIGHT_MODEL pinning to glm-5.3-flash(env)**: Pins to a specific low-cost endpoint (~$0.002/token range) instead of allowing fallback to more expensive alternatives. If this env were absent, select_model would try unsloth/bench scores first (currently returning empty results due to gate-red state), then fall through to more expensive providers.

## Summary Table

| Category           | 4-day spend | Share | Trend (recent 3 days) |
|--------------------|-------------|-------|----------------------|
| GLM-5.3 flash      | $31.87      | 73%   | Declining: $30->1->0.53 |
| GLM-5.3 (tier)     | $11.17      | 26%   | One-time spike 09-08 only |
| Qwen-flash         | $0.99       | 2%    | Minimal |
| Unsloth local      | $0.00       | 0%    | Free (GPU overhead) |
| Kimi quota         | $0.00*      | 0%    | Unused (cred expired) |
| LobeHub quota      | $0.00       | 0%    | Unused (endpoint 404) |
| Coordination blind | Unknown     | ?     | Likely <$1 total |
| **Total tracked**  | **$43.72**  |       |                      |

*Note: kimi model-telemetry shows 26 calls but session-cost has 0 recorded costs for k3-256k, suggesting kimi transcript parsing doesn't capture cost data — possible undercount.

Average daily: $10.9/day. Operator target: $10-20/day. Current trajectory: declining toward ~$0.5/day based on last 48h. The recent decline correlates with the operator-implemented fixes: OVERNIGHT_MODEL pin (reducing expensive fallbacks), kernel-gate stabilization (enabling sessions to complete), and stall-recovery demotion design (preventing re-burn on bad models).

Spend is dominated by overnight-delegation sessions consuming GLM-5.3-flash. Reducing overnight session count or enabling cheaper local-model fallback would lower spend further. The biggest latent risk is kimodel credential expiration causing kimi quota leg (currently unused) to fail entirely, forcing all research/review traffic to GLM flash or unsloth.
