# hngh-route v0 — design note (seeded from the 2026-10-30 fleet sweep)

## Problem
Local-model-dependent sessions need a dispatcher that (a) routes each request
to the right resident model by duty class, (b) waits patiently instead of
erroring on a busy server, (c) records provenance, and (d) never hardcodes
what the fleet is. liteLLM rejected: heavy, churn-prone, security-churn
history. We roll ~200 lines of bash+curl under the same rules as every hngh
tool.

## Measured fleet (fleet-sweep 2026-10-30, studio keep-multiple ON)
| duty | model | why |
|---|---|---|
| router/dispatcher + summarizer | LiquidAI/LFM3-1.7B (BF16, 4.5 GB) | 130 tok/s, best summary fidelity, 131k ctx ceiling |
| coder | nvidia/Nemotron-3.5-Bolt-E4B-4GB (Q4_K_M, 5.7 GB) | only small model producing correct, applying diffs; the 12 GB E4B remains the FILL coder |
| decider | StartLux-Decision-v1.1-2B-Instant **Q8_0** (2.01 GB, on disk; Q4_K_M costs 1.6–3.8 points — do not use) | SystemOne decision model: 25–52 ms medians on server hardware, prompt-bidirectional, one forward pass |
Category contract (research 2026-10-30, see wiki `systemone-decision-models-2026-10.md`): `state + questions{choice|noul|score}` → typed answers + per-option probabilities + confidence. Batch law: many questions on ONE context cost ~no latency (64 questions ≈ 0.4 s). Operating rules: DESCRIBE your options (bare labels misroute); calibrate confidence cutoffs per model; escalate the unsure ones to a human/orchestrator.

**Runtime recipe (the reason plain chat failed):** StartLux/decider GGUFs do NOT produce decisions via plain chat — the option-letter readout, prompt format and temperatures live in their `startlux-decide` package, and the weights are prompt-BIDIRECTIONAL: launch llama-server with `--override-kv qwen35.attention.causal=bool:false --parallel 1 --ctx-checkpoints 0 -b 16384 -ub 16384` (stock batching costs 7.7 points; causal read costs 27 of 48). pplx-decider-flash is the same family (causal backbone + NON-CAUSAL layers + 255-row decision readout head; NOT block-diffusion as we first labelled it) — our studio build is llama.cpp 0.8.0-dev build 11985 ≥ b11447, so it HAS decision support; the studio UI just doesn't pass the override flags → decider duty runs on a manually-launched llama-server on a spare port, or via the `startlux-decide`/`pplx_decider` packages. Remote reference economics: $0.02–0.042/M input, output free.
**License caveat:** StartLux code Apache-2.0 but weights **CC-BY-NC** — fine for internal hngh duty, NOT servable in a paid offering. OneJev1.5-4B (registered, unswept) is the commercial-weights candidate to probe next.
**SystemOne direction (operator, 2026-10-30):** hngh tracks complex state across the system and makes active predictions/corrections; SystemOne-class models do the rapid routing/categorization/multiple-choice reactions (Jev-at-Doom class, ~10 decisions/s). Decision-latency sweep (choices/sec, JSON adherence, state-reaction drill) is queued for OneJev + StartLux-2B.
Standing fleet: LFM3 + Nemotron-4GB @32768 = 10.07 GB cumulative, verified
resident and answering.

## v0 shape (two scripts, no daemon)
- `hngh-route submit <class> <payload-file>` — appends to
  `~/.local/state/hngh/route/queue.jsonl` `{id, ts, class, payload, status:queued}`.
- `hngh-route drain [--follow]` — pops queued items; route table defaults to
  the duty ranking above; POST to the studio with the resident model for the
  class; patient semantics: timeout 600 s, retry on busy/unreachable with
  30 s backoff ×3 before marking `failed:busy` (the caller's request never
  errors mid-queue — it waits or fails explicitly at the end).
- Provenance: `results.jsonl` `{id, model, latency_s, tokens, status}`.
- Multi-resident aware: reads `/api/inference/loaded-models` (context_length
  ALWAYS re-confirmed after any load — sweep gotcha: a `model` field with a
  single resident triggers auto-switch at NATIVE ctx; omit `model` or target
  a specific resident).
- VRAM line: never request a load that pushes cumulative residency past
  17 GB; report instead (desktop is on the iGPU now — the line protects
  inference headroom, not the desktop).

## Deliberately not in v0
No daemon, no priority preemption, no GPU partitioning, no vision routing
(unmeasured), no remote-lane routing (weekly batched sessions are manual).
v1 candidates after a week of queue data: class weights, load-balancing
between two residents of the same class, an admission rule tied to the
quota-pacing doctrine.

## Build order
Fill-funnel item batch (the funnel is the factory): 1) route table + submit,
2) drain + patient retry, 3) provenance + loaded-models check, 4) selfcheck
script. Four single-file items, additive, no hidden callers.

## VERIFIED: studio-native decider serving (2026-10-30, live)
The studio itself serves `POST /v1/systemone` (settings: `/api/settings/systemone`,
dropdown of 14 catalog models with sizes + llama_cpp_only flags; request schema
in the studio OpenAPI). Decider duty needs NO manual llama-server flags for the
catalog models (laya/kev/lev/julia) — the override-kv dance is only for
StartLux/pplx GGUFs outside the catalog. Live recipe (verified, laya-multilingual
200 in 1.23 s once loaded, 0.68 GB): choice questions take `criteria` as an
OBJECT describing each option; score questions take `criteria` as an ARRAY of
1–10 level strings; strict pydantic rejects extras. Full recipe:
kb/llm-wiki wiki `syntheses/systemone-decision-models-2026-10.md`.
hngh-route's decider class = this endpoint; route table: laya-multilingual
(multilingual/cheap), kev-4b (default), julia-1 (sub-GB, CPU-able).
