# Kimi and LobeHub Quota Utilization - Measurement (2026-09-10 ~13:00Z)

## 1. Consumption (last 3 days: 09-08 through 09-10)

Data source: automation/dashboard/telemetry.db (kind='model' rows).

| Model     | Daily Cap | 09-08 | 09-09 | 09-10 | 3-Day Total | Utilization |
|-----------|-----------|-------|-------|-------|-------------|-------------|
| Kimi k3-256k | 40/day  | 23    | 2     | 1     | 26          | 22% of cap  |
| LobeHub   | 50/day    | 0     | 0     | 0     | 0           | 0% of cap   |
| Unsloth (local, free) | N/A | 23    | 25    | 21    | 69          | N/A         |

**Kimi calls by caller:** ALL 26 calls originate from `33-research-beat.sh` (the hourly research beat's share-pin mechanism). No delegated overnight sessions consumed kimi - every session over this window ran either `unsloth/Ornith-1.0-35B-GGUF(local-bench)` or `openrouter/z-ai/glm-5.3-flash(env)` per agent-handoffs.md.

**LobeHub calls:** Zero across all 3 days despite `lobehub-research-share=6` in cadence-params.tsv. The endpoint consistently returns HTTP 404. Even when the share rotation triggers (`run_n % 6 == 0`), lobehub_chat fails silently without emitting telemetry.

### Usage breakdown (unsloth as comparison)
Unsloth calls today (21) break down approximately:
- ping-hourly.sh summarization (~7 calls, once/hour)
- morning-digest.sh (~3)
- 04-review-prep.sh (~2)
- 19-ux-review.sh (~2)
- night-research.sh (~1)
- 33-research-beat.sh local branch (~6)

These unsloth calls represent **review/digest operations**, not delegation work. They are intelligence-shaping bounded calls using the free local model instead of burning paid quotas. This is by design: the code path in `lib/model.sh` routes to unsloth first when no higher rung proves worth spending money on.

## 2. Credential Health Status

Both endpoints persistently failing since their configuration was introduced 2026-09-07:

| Service     | Config Key       | Value (cadence-params.tsv)                        | Latest Check                     | Diagnosis                                    |
|-------------|------------------|----------------------------------------------------|----------------------------------|----------------------------------------------|
| Kimi        | kimi-endpoint    | https://api.kimi.com/coding/v1/chat/completions    | http=401 (always)                | API key invalid/expired; machine can fix only if operator provides fresh KIMI_AI_KEY or MOONSHOTAI_API_KEY env var |
| LobeHub     | lobehub-endpoint | https://app.lobehub.com/api/v1/responses           | http=404 (always)                | Endpoint dead; possible LobeHub migration/API change; requires investigation before retry |

Configuration details:
- **Kimi:** Source env is `MOONSHOTAI_API_KEY` (via lib/model.sh:318: `key="${KIMI_AI_KEY:-${KIMI_FOR_CODING_KEY:-${MOONSHOTAI_API_KEY:-}}}"`). The credential-health check shows "armed via env" meaning the key file exists but the 401 response indicates the key itself is rejected by the API server. This is an **operator-owned credential issue** - the key was likely expired and needs re-acquisition.
- **LobeHub:** Source env is LOBEHUB_AGENT_ID (from cadence-params.tsv row) with key loaded from `~/.config/hngh/lobehub-key`. The 404 response indicates the endpoint URL itself is wrong or the service migrated. This is a **configuration issue** that may be fixable by updating lobehub-endpoint row, but requires understanding the new LobeHub API shape.

Neither issue prevents the system from operating - both legs gracefully skip via fail-closed semantics. But it means **both paid quotas are sitting at zero consumption regardless of share-row pinning**.

## 3. Routing Status - stall-recovery Plan Steps 9 and 10

Both remain unchecked (11 total steps, 0 checked):

- **Step 9 (Wire pre-paid quota models into session routing):** Would read `session-model-preference` cadence param row in select_model, preferring quota models (kimi/lobehub) over paid-fallback when their keys/config are present. This would allow automated sessions to consume kimi quota during normal delegated execution. Currently skipped because OVERNIGHT_MODEL=openrouter/z-ai/glm-5.3-flash(env) in both unit files short-circuits select_model before reaching any quota logic.

- **Step 10 (Fix review beat's model selection):** Would route review beats (and digest model leg) through the same quota ladder, consuming kimi/lobehub instead of unsloth for review synthesis. Currently review beats use whichever model select_model returns (unsloth/local-bench when no quota routing).

**Impact if executed:** Both steps would enable actual quota consumption against kimi and lobehub caps. Until they land, quota sits at 0/40 and 0/50 daily unused regardless of researcher pinning behavior. Step 9 enables delegated-session quota spend; step 10 enables review/beats quota spend. Together they transform zero-consumption into active billing.

## 4. Research Lane State

Current state of automation/research-lines.tsv (39 lines):

| Phase        | Count | Example lines                                                    |
|--------------|-------|------------------------------------------------------------------|
| crystallized | 0     | None                                                             |
| contracting  | 0     | None                                                             |
| planned      | 1     | synth-2026-09-10-3                                               |
| reviewing    | 1     | ctx-structured-briefs                                            |
| reviewed     | 35    | All remaining historical and synthesized lines                   |

With 35 reviewed lines and only 1 planned + 1 reviewing line, the research pipeline operates near capacity exhaustion. The single planned line `synth-2026-09-10-3` was picked up by the midnight 33-research-beat.sh run (00:04Z), which incremented run_n, evaluated `run_n % kimi_share` (where kimi_share=3), hit a boundary, set MODEL_PIN=kimi, invoked kimi_chat, and produced the one kimi call logged today.

The next replenishment requires `demand_synthesize()` firing - which happens when pick_line returns empty AND the research-demand-floor threshold is exceeded. If planned lines accumulate above floor, the synthesizer fires one local-model call per UTC day to propose new subjects. Until then, the pool slowly drains toward zero planned entries.

**Note:** The kimi call on 09-10T00:04 came from this planned line being advanced, NOT from share-pin of an existing crystallized line. When all lines are reviewed, share-pin still fires but there is nothing to process - the model call hits an empty input and emits telemetry with zero tokens/cost. It does burn quota (counted in telemetry) without producing useful work. This is a subtle waste vector that step 9's routing would exacerbate: delegated sessions would also trigger futile kimi calls if the quota legs are enabled while credentials fail.

## Gap Analysis

Four independent factors block appropriate quota consumption right now:

1. **Credential failures:** kimi returns 401, lobehub returns 404. These are persistent since 09-07. Even if routing were enabled, calls would immediately error out and count against the daily cap without producing output. Fix priority: kimodel API key renewal (operator action) is the fastest win; lobehub endpoint diagnosis is second.

2. **Stall-recovery steps 9+10 pending:** Without these two steps, the entire delegated execution path short-circuits via OVERNIGHT_MODEL env override before any quota-leg code executes. Setting the env pins the lane deterministically away from quota usage. Enabling quota routing would require unpinning OVERNIGHT_MODEL or modifying select_model to honor quota legs even when env is set.

3. **Research line depletion:** With 35 reviewed lines and only 1 planned + 1 reviewing, share-pin-based quota consumption is minimal. Share-pin still generates calls when run_n hits boundaries (every 3rd for kimi, every 6th for lobehub) but with empty inputs those calls produce zero value and only burn token counts. The pipeline needs planned lines replenished for meaningful quota consumption.

4. **No delegated sessions hitting quota lanes:** Every overnight session since 09-08 used either unsloth/local-bench or openrouter/z-ai/glm-5.3-flash(env). The GLM Flash sessions (2 on 09-09, 2 on 09-10) all failed - rc=0 cancelled or rc=124 dead - never landing code or consuming quota. Unsloth local bench handled the bulk (14 on 09-09, 2 on 09-10) but uses zero budget.

## What Executing Steps 9 and 10 Would Change

If both steps landed:

- **Delegated sessions** would attempt kimi/lobehub routing through select_model. If credentials were fixed simultaneously, sessions could burn paid quota intelligibly instead of burning unsloth slots indefinitely. Without fixed credentials, sessions would hit HTTP errors immediately - wasting quota counts against 40/50 caps with zero ROI.

- **Review beats** would consume kimi quota for review synthesis. Currently using unsloth (free). A review beat calling kimi at 40/day cap cost represents real billing impact proportional to review frequency (daily).

- **Share-pin behavior** in 33-research-beat.sh would continue exactly as-is: pinning kimi every 3rd run and lobehub every 6th run. The share rows already exist and work correctly. The difference is whether the pinned model successfully completes calls (credential permitting).

## Summary Table

| Metric                 | Current              | If Steps 9+10 + Fixed Credentials  | If Steps 9+10 Only |
|------------------------|----------------------|-------------------------------------|---------------------|
| Kimi daily             | 1/day (research only)| Up to ~10/day (delegation + review)| Up to ~10/day       |
| Kimi monthly estimate  | ~30                  | ~300                                | ~300                |
| Lobehub daily          | 0/day                | Up to ~8/day                        | 0/day (still fails) |
| Lobehub monthly est.   | 0                    | ~240                                | 0                   |
| Cost signal            | None                 | Significant                         | None                |
| Blocked by             | Env pin + creds + empty pipelines | Creds + pipeline depletion | Creds               |

The most efficient next action is fixing the kimi API key (operator action, takes minutes). After that, enabling step 9 would immediately start utilizing the kimodel quota leg for delegated sessions. Step 10 follows naturally. LobeHub endpoint diagnosis requires more effort (understanding LobeHub API changes) and should be sequenced after kimodel is operational.

Without credential fixes, executing steps 9+10 has negative utility: it adds quota consumption paths that all immediately fail, wasting daily cap budgets against 401/404 errors. The dependency chain is: fix credentials -> enable routing -> monitor utilization -> tune share rows.
