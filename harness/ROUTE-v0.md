# hngh-route v0: design note (seeded from the 2026-10-30 fleet sweep)

## Problem
A session that depends on a local model needs a dispatcher. It has to send each
request to whichever resident model holds that duty, wait rather than error when
the server is busy, write down where each answer came from, and stay ignorant of
the fleet's shape so a new model can be added without touching the code.

liteLLM was rejected: heavy, churn-prone, and carrying a security-churn history.
So we roll 391 lines of bash+curl, under the same rules every hngh tool
already follows.

## Measured fleet (fleet-sweep 2026-10-30, studio keep-multiple ON)

| duty | model | why |
|---|---|---|
| router/dispatcher + summarizer | `LiquidAI/LFM3-1.7B-GGUF` | 130 tok/s, best summary fidelity, 131k ctx ceiling; the sweep's resident `LiquidAI/LFM3-1.7B` was BF16, 4.5 GB |
| coder | `unsloth/NVIDIA-Nemotron-3.5-Bolt-E4B-GGUF` | the sweep's 4 GB `nvidia/Nemotron-3.5-Bolt-E4B-4GB` (Q4_K_M, 5.7 GB) was the only small model producing correct, applying diffs; the 12 GB E4B remains the FILL coder |
| decider | `laya-multilingual` via the studio's `/v1/systemone` | flag-free, no manual llama-server flags |

The decider duty has a measured local alternative. `StartLux-Decision-v1.1-2B-Instant`
**Q8_0** (2.01 GB) — **MEASURED PASS** (sweep 2026-10-30): 57.5 dec/s sustained
(11× the ≥5 bar), 100% parse, 8/10 state-reaction (9/10 reworded), order-invariant
picks. OneJev-4B Q6_K fails on discrimination (3/10, order-flippy) despite 22.7
dec/s — second-opinion only near StartLux's threshold.

### Category contract
Research 2026-10-30; wiki `systemone-decision-models-2026-10.md`.

The call shape is `state + questions{choice|noul|score}`, and the answer is typed
answers plus per-option probabilities plus confidence. Batch law: many questions
on ONE context cost ~no latency, 64 questions ≈ 0.4 s.

Operating rules. DESCRIBE your options; bare labels misroute. Calibrate
confidence cutoffs per model. Escalate the unsure ones to a human/orchestrator.

### Runtime recipe
This is the reason plain chat failed. StartLux/decider GGUFs do NOT produce
decisions via plain chat. The option-letter readout, the prompt format and the
temperatures live in their `startlux-decide` package. The weights are
prompt-BIDIRECTIONAL, so launch llama-server with:

`--override-kv qwen35.attention.causal=bool:false --parallel 1 --ctx-checkpoints 0 -b 16384 -ub 16384`

Stock batching costs 7.7 points. Causal read costs 27 of 48.

pplx-decider-flash is the same family: causal backbone, NON-CAUSAL layers, and a
255-row decision readout head. We first labelled it block-diffusion. It is not.

Our studio build is llama.cpp 0.8.0-dev build 11985, which is ≥ b11447, so it
HAS decision support. The studio UI just doesn't pass the override flags. Decider
duty therefore runs on a manually-launched llama-server on a spare port, or via
the `startlux-decide`/`pplx_decider` packages.

Remote reference economics: $0.02–0.042/M input, output free.

### License caveat
StartLux code is Apache-2.0 but the weights are CC-BY-NC. Fine for internal hngh
duty, NOT servable in a paid offering. OneJev1.5-4B (registered, unswept) is the
commercial-weights candidate to probe next.

### SystemOne direction (operator, 2026-10-30)
hngh tracks complex state across the system and makes active
predictions/corrections. SystemOne-class models do the rapid
routing/categorization/multiple-choice reactions, the Jev-at-Doom class, at
~10 decisions/s.

Sweep DONE (decider-sweep results.md). The serving path is confirmed. Raw
llama-server serves NEITHER model: `/v1/systemone` → 501, because the GGUFs lack
`<arch>.decision.type` metadata. The vendor packages are mandatory —
`startlux-decide` 1.1.0 with `--backend llamacpp`, OneJev via `qev --llama-url`.
The override-kv flag is a NO-OP for StartLux; the GGUF already declares
causal=false. OneJev upstream now 401s, so Q6_K is used. The studio catalog
(laya/kev/lev/julia) remains the flag-free alternative for lighter decisions.

### Source-level deltas
unsloth `main` @ 673a44b. Full brief `local://unsloth-decision-api-brief.md`,
wiki `systemone-decision-models-2026-10.md`.

The studio's own `POST /v1/systemone` is FIRST-CLASS for this duty. No manual
flags for its catalog: Laya/Kev/lev/Julia/Clef. The override-kv dance is only for
Perplexity pplx-decider GGUFs on stock llama.cpp.

Limits. 1–64 questions per call. Choice questions carry 1–255 options. Score
criteria carry 1–10 ordered levels. State is ≤200k chars. Optional images (≤4)
and audio (≤8) are allowed, so multimodal decisions exist. Threshold on
**probabilities**, not confidence. No batching across calls.

The decision server unloads after 300 s idle. The first request reloads in
10–20 s, so `hngh-route drain` must tolerate reload latency.
`GET /v1/models?output_modalities=decisions` discovers the dropdown.

TypeSafe SDK compat comes via `TYPESAFE_BASE_URL`/`TYPESAFE_API_KEY`. The
`unsloth` pip package ships `FastDecisionModel`/`DecisionTrainer`, so training
bespoke deciders on own data — pantheon decision corpora — is the v1 path.

### Standing fleet
LFM3 + Nemotron-4GB @32768 = 10.07 GB cumulative, verified resident and
answering.

## v0 shape (two scripts, no daemon)

Two scripts. No daemon.

`hngh-route submit <class> <payload-file>` appends to
`~/.local/state/hngh/route/queue.jsonl`:

    {id, ts, class, model, payload_file, note, status:queued}

`hngh-route drain [--follow]` pops queued items. The route table defaults to the
duty ranking above. It POSTs to the studio with the resident model for the
class.

Patient semantics: timeout 600 s, retry on busy/unreachable with 30 s backoff ×3
before marking `failed:busy`. The caller's request never errors mid-queue. It
waits, or it fails explicitly at the end.

Provenance lands in `results.jsonl`:

    {id, model, latency_s, status}

Multi-resident aware. It reads `/api/inference/loaded-models`. context_length is
ALWAYS re-confirmed after any load. The sweep gotcha: a `model` field with a
single resident triggers auto-switch at NATIVE ctx, so omit `model` or target a
specific resident.

VRAM line. Never request a load that pushes cumulative residency past 17 GB;
report instead. The desktop is on the iGPU now, so the line protects inference
headroom, not the desktop.

## Deliberately not in v0

No daemon. No priority preemption. No GPU partitioning. No vision routing; it
is unmeasured. No remote-lane routing: daily lane sessions are manual, within
the daily quota allowance, and weekly is the retrospective layer. The check-in
skill's cadence layers are ~5 min machine probes, hourly progression checks
during work blocks, daily funnel cycles, and weekly review.

v1 candidates, after a week of queue data: class weights, load-balancing between
two residents of the same class, an admission rule tied to the quota-pacing
doctrine.

## Build order

Fill-funnel item batch. The funnel is the factory.

1. route table + submit
2. drain + patient retry
3. provenance + loaded-models check
4. selfcheck script

Four single-file items, additive, no hidden callers.

## VERIFIED: studio-native decider serving (2026-10-30, live)

The studio itself serves `POST /v1/systemone`. Settings live at
`/api/settings/systemone`; the request schema is in the studio OpenAPI. The
dropdown lists 14 catalog models with sizes and llama_cpp_only flags.

Decider duty needs NO manual llama-server flags for the catalog models
(laya/kev/lev/julia). The override-kv flags are only for StartLux/pplx GGUFs
outside the catalog.

Live recipe, verified: laya-multilingual, 200 questions in 1.23 s once loaded,
0.68 GB. Choice questions take `criteria` as an OBJECT describing each option.
Score questions take `criteria` as an ARRAY of 1–10 level strings. Strict pydantic
rejects extras.

Full recipe: kb/llm-wiki wiki `syntheses/systemone-decision-models-2026-10.md`.

hngh-route's decider class is this endpoint. The route table:

| model | role |
|---|---|
| laya-multilingual | multilingual/cheap, default |
| kev-4b | alternate |
| julia-1 | sub-GB, CPU-able |
