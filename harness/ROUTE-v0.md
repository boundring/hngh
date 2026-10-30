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
| decider | none | no working decider in the fleet; use LFM3 + a JSON schema constraint |
Excluded: pplx-decider (block-diffusion; causal path emits garbage), DeepSeek-V4.1-Flash (sidecar-only GGUF, no base weights).
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
