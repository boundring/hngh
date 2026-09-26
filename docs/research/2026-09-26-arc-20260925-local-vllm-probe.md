# local-models: what do a uv venv + python-vllm-rocm smoke on RX 7900 XT measure for billion-context compression, and under what VRAM/coordination halts?

Status: crystallized 2026-09-26 from research line `arc-20260925-local-vllm-probe`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-arc-20260925-local-vllm-probe.md.

# Research Line: local-models — Final Contracted Record

**Lifecycle state:** contracted.  
**Line ID:** `local-models: what do a uv venv + python-vllm-rocm smoke on RX 7900 XT measure for billion-context compression, and under what VRAM/coordination halts?`  
**Date:** 2026-09-26  
**Model used during expansion:** `kimi:k3-256k`  
**Wall clock (expansion phase):** 58.0s  

---

## Findings

### F1. Hardware envelope
The RX 7900 XT provides 24 GB GDDR6. This is the only hardware parameter that enters the VRAM budget calculation for any billion-context inference attempt on this platform.

### F2. Smoke path character
The `uv venv + python-vllm-rocm` smoke is a **reproducibility harness**, not a compression measurement. It confirms that:
- The ROCm toolchain builds under `uv`
- A model loads into VRAM
- A short generation completes

It does **not** measure context compression, KV-cache utilization, or sustained long-context behavior.

### F3. VRAM budget (arithmetic, not measured)
For a 7B model on 24 GB:
- FP16 weights: ~14 GB → ~10 GB remaining for KV cache + activations
- 8-bit weights: ~17 GB → ~7 GB remaining

These are derived arithmetically from upstream model size tables and ROCm memory accounting. They are **not** logged by any hngh or hngh-automation run observed in this line.

### F4. Halt taxonomy (single GPU)
Three distinct failure modes on a single RX 7900 XT:
1. **KV-cache overflow** — steady-state context exceeds remaining VRAM
2. **Prompt-ingestion spike** — transient peak on first tokens of a long prompt, before cache is populated; can OOM a context that would fit in steady state
3. **ROCm allocator fragmentation** — OOM under sustained long-context load despite nominally sufficient capacity (upstream claim; unverified from this line)

### F5. Multi-GPU coordination framing is incorrect for single-card
On a single-card host there is no inter-GPU coordination halt. The only coordination surface is **host↔device transfer** — i.e., any context offloading hngh performs to reach billion-context scale. The metric that matters is **transfer bandwidth vs. attention stall time**.

---

## Recommendations

### R1. Reclassify the smoke as a fixture, not a benchmark
The smoke should be wired as a pass/fail gate (env builds, model loads, one short generation completes on ROCm) that **precedes** any compression measurement run. If hngh-automation currently treats smoke success as evidence about billion-context behavior, that conflation should be removed — it is the single most likely source of false confidence in this line.

### R2. Make VRAM budget an explicit, measured quantity
Every hngh compression run should record:
- (a) weights footprint
- (b) KV-cache footprint at measurement time
- (c) peak allocation during prompt ingestion

Without these three numbers attached to a run, any stated compression ratio is unfalsifiable. Whether hngh already emits this telemetry is unverified — that check is the first concrete task.

### R3. Instrument the three single-GPU halts as distinct failure signatures
hngh-automation should distinguish KV-cache overflow, prompt-ingestion spike, and ROCm allocator fragmentation in failure output rather than collapsing them into "OOM," because each has a different mitigation:
- KV-cache overflow → quantized KV cache
- Prompt-ingestion spike → chunked prefill
- ROCm allocator fragmentation → allocator tuning / restart policy

### R4. Drop the multi-GPU coordination framing; measure host↔device transfer instead
If hngh pursues billion-token contexts on 24 GB at all, offloading is the mechanism, and the metric that matters is **transfer bandwidth vs. attention stall time**.

---

## Open Threads

| Thread | Status | Notes |
|---|---|---|
| Whether hngh already emits (a)/(b)/(c) VRAM telemetry | Open | First concrete task per R2 |
| ROCm allocator fragmentation hypothesis | Open | Requires allocation logging to confirm or falsify |
| Whether `uv venv + python-vllm-rocm` smoke is currently treated as compression evidence in hngh-automation | Open | Per R1, needs audit |
| Host↔device transfer bandwidth measurement methodology | Open | Per R4, needs design |

---

## References

- `research-lines.tsv` — this repository; line state given by the line itself
- `hngh` kernel repository at `[redacted path] — **contents not enumerated during this transition; no file paths cited**
- `uv` documentation — upstream; behavior claims flagged as unverified from this line
- `python-vllm-rocm` — upstream; behavior claims flagged as unverified from this line
- `RX 7900 XT` hardware spec — upstream; 24 GB GDDR6 stated as known hardware parameter

---

**Verifiability notice:** No file paths inside the hngh kernel repository are cited in this record. Doing so would fabricate grounding, as the repository contents were not enumerated during this transition. Claims about `uv` and `vllm-rocm` behavior rest on upstream documentation and are flagged as unverified. All arithmetic (F3) is derived from public model size tables and ROCm memory accounting conventions, not from measured data.
