# Local Model Benchmarks (20GB VRAM / 32GB DDR5)

Decision reference for model selection, updated 2026-07-31. Weights: stability
and token output speed first, quality second. Feeds the planned M8
model-management plugin.

## Daily-driver verdict: gemma-4-12b-it-qat (confirmed)

**Gemma 4 12B QAT + MTP stays the daily driver.** Official signal for
agentic/coding work: LiveCodeBench v6 **72.0**, Codeforces ELO **1659**, Tau2
**69.0**, native function calling; QAT keeps quality near BF16 and MTP yields
~1.4–2.2× faster inference ([model card](https://huggingface.co/unsloth/gemma-4-12b-it-qat-GGUF), [Gemma 4 docs](https://unsloth.ai/docs/models/gemma-4), [Unsloth MTP](https://unsloth.ai/docs/models/mtp)).

**Qwythos-9B (Qwen3.5-base Mythos) is the long-context/experiment slot, not the
default**: 1M-class context, +34 MMLU vs base, self-reported 7/7 tool-use — but
its own card warns about over-committing on specifics, and community threads
report tool/template loops until chat-template fixes
([card](https://huggingface.co/empero-ai/Qwythos-9B-Claude-Mythos-5-1M-GGUF)).

## Ranked alternates (already downloaded)

| Rank | Model | Coding evidence | Caveats |
|---|---|---|---|
| 1 | **gemma-4-26B-A4B-it-qat** (MoE, 3.8B active) | SWE-bench **77.1**, Terminal-Bench **51.5** | heavier to load; keep as the "big job" alternate |
| 2 | **Qwen3.6-27B-MTP** | SWE-bench **77.2**, Terminal-Bench **59.3**, MTP ~1.5–2× faster | 27B at Q3_K_XL — slower loads, tighter fit |
| 3 | **Devstral Small 2 24B** | SWE-bench **68.0**, SE-agent branding | card recommends vLLM; llama.cpp/ROCm least proven |
| 4 | **Qwen3.6-35B-A3B** | SWE-bench **73.4** headline | tightest memory fit on 20GB; offload risk |

Cards: [26B-A4B](https://huggingface.co/unsloth/gemma-4-26B-A4B-it-qat-GGUF) · [Qwen3.6-27B](https://huggingface.co/Qwen/Qwen3.6-27B) · [Devstral](https://huggingface.co/unsloth/Devstral-Small-2-24B-Instruct-2512-GGUF) · [Qwen3.6-35B-A3B](https://huggingface.co/Qwen/Qwen3.6-35B-A3B)

## Speed expectations (RX 7900-class ROCm, llama.cpp HIP)

- **gemma-4-12b QAT**: ~35–45 tok/s raw decode; MTP lifts materially on supported builds.
- **Qwythos-9B Q5_K_M**: ~50–90 tok/s community-reported (NVIDIA 4080-class ~70–95); usually faster than the 12b *when the runtime behaves*.
- **ROCm caveats**: llama.cpp ROCm decode has been reported ~20% slower than Vulkan on 7900 XTX, and AMD Flash Attention silently falls back unless K/V quantization matches ([llama.cpp discussion #20934](https://github.com/ggml-org/llama.cpp/discussions/20934)).

## Measured reality on this machine (2026-07-31)

Daily driver at 219,904 ctx: **6.4 GB weights + 0.2 GB mmproj + 9.8 GB KV + 0.24 GB MTP ≈ 16.6 GB resident** of 20,194 MB. Context length, not weights, is the residency lever — see `.omc/plans/multi-model-topology.md` (sysconfig_mgmt repo) for the full topology decision.

## Selection policy (unchanged, now evidenced)

1. gemma-4-12b-it-qat for everything routine (stability + speed + function calling).
2. Qwythos-9B for >220k-context sessions, deliberately invoked (accept switch latency + template caveats).
3. gemma-4-26B-A4B for planned heavy coding jobs; Qwen3.6-27B-MTP as its runner-up.
4. Qwen3.6-35B-A3B and Devstral stay shelved unless a specific need appears.
