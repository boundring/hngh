# C1 vllm-rocm probe (2026-09-25)

principle: measure before wiring -- a bounded probe with explicit halt
conditions converts the local-model lane from speculation into a recorded
envelope, so the completion graph's arc C gates on evidence, not hope.

adversarial: a probe could leave a daemon behind or a rotted venv -- the
server was killed and verified (pgrep empty, GPU0 back to the 1.44 GB
baseline); the venv is disposable userspace (~/.local/share/hngh-vllm-venv)
rebuildable in minutes from the pins below. Nothing entered the repo's
automation surface, and no service row was enabled.

Operator authority: m07360 (billion-context local models, venv not global,
stall/bad-behavior steering with quota-model escalation); plan slice C1 of
docs/project/completion-graph.md; VRAM gate pre-checked (19.9 GB free on
GPU0 >= 12 GB).

## What ran

- Pre-checks: rocm-smi free VRAM 19.9 GB on GPU0 (21.45 total, 1.52 used);
  uv 0.12.19.
- Venv: `~/.local/share/hngh-vllm-venv`, Python 3.10 (PyPI has no
  `python-vllm-rocm`; the real distribution is `vllm-rocm` 0.6.3 =
  vllm 0.6.3.dev193+gfd47e57f.d20241014, cp310-only wheel).
- Server: `vllm serve Qwen/Qwen2-0.5B-Instruct --max-model-len 32768` (then
  16384) `--gpu-memory-utilization 0.55 --dtype float16 --port 8001
  --enforce-eager`; OpenAI-compatible API on 127.0.0.1:8001.

## Measured envelope

- Startup: 25-54 s; basic chat round-trip 1.5 s (27 prompt + 10 completion
  tokens).
- Context: KV headroom ~44143 blocks x 16 = ~706k tokens at util 0.55 for
  the 0.9 GB model (fp16 KV ~12 KB/token). Needle-in-haystack at 10,485
  prompt tokens retrieved exactly (`GLM-7742-PROBE`) in 2.1 s (eager).
- Ceiling: a ~21.4k-token prefill (1338 KV blocks) crashed the engine --
  `ValueError: could not broadcast input array from shape (1338,) into
  shape (512,)` in the ROCm flash-attention block-table path. Operational
  ceiling on this stack: ~20k prompt tokens; the configured 32k window is
  not usable. Billion-context target NOT met by the era-0.6.3 ROCm build;
  C2 endpoint wiring stays a seeded node gated on a current gfx1100-capable
  vllm-rocm release.

## Environment facts (the hard-won pins)

- `vllm-rocm` pins NO torch: bare install pulls CUDA torch and dies on ABI
  (`_core_C.ScalarType`). Required: `torch==2.5.1+rocm6.2` from
  `https://download.pytorch.org/whl/rocm6.2` (HIP 6.2.41133, gfx1100 OK).
- vllm's ROCm platform detection requires the `amdsmi` module (installed
  7.0.2) and FAILS with `Failed to infer device type` without it.
- `ROCR_VISIBLE_DEVICES` must be UNSET (an empty string masks all HIP
  devices); select the GPU with `HIP_VISIBLE_DEVICES=0`. The global
  torch 2.14+rocm7.2 (unsloth's) honors ROCR and is untouched.
- Version fences: transformers must be 4.46.x (5.x injects rope_scaling
  dicts that trip vllm 0.6.3's `assert "factor" in rope_scaling`);
  huggingface-hub < 1.0 (0.36.2); outlines 0.0.46 with a vendored
  `pyairports` shim -- PyPI `pyairports 0.0.1` is a squatter placeholder
  (ships `sample/`, `byted-wandb` bin, no module).
- gfx1100 notes: hipBLASLt unsupported -> hipblas fallback; custom
  all-reduce disabled; ROCmFlashAttention backend used; SWA unsupported
  in Triton flash attention.

## Halt/park ledger

No park conditions triggered: VRAM gate held, install succeeded after the
torch pin, no stall (longest launch 54 s). The engine crash at 21.4k tokens
is a recorded finding, not a halt -- it bounds the envelope and defers C2.

Verdict recorded in completion-graph node C1 (ticked); C2/C3/C4 remain
open seeds.
