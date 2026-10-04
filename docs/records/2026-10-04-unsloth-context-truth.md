# 2026-10-04 — Unsloth context-window truth: quant audit, fail-closed pins, catalog mirror

Priority operator interjection (m11017): "a boatload of errors in unsloth for
bad API calls, Hngh attempting to set way too high a context for a model too
big for our VRAM under those settings." Follow-up (m11286): "check for the
specific quantizations we're using, not just the model names."

## Symptom

453 errors in 24h in the unsloth-studio journal, all one shape:

    responses stream upstream error: status=400 ... type=exceed_context_size_error
    n_prompt_tokens=17772 n_ctx=8192

Bursts at :07-:08 and :36-:38 past the hour (cadence beats); ten
near-identical requests within the same second (swarm fan-out;
llama-server runs `--parallel 4`). Failing endpoint: `/v1/responses`
streaming — jcode's wire API, not hngh's `/v1/chat/completions` leg.

## Root cause

jcode's `~/.jcode/config.toml` declared hub-advertised context windows
(Qwen3.8-27B 102400, Ornith-1.0-9B 37376, Ornith-1.5-9B 262144) while the
studio's llama-server had been launched (14:35Z) with a small `-c` and
`--fit off`. Client packed ~17.8K-token prompts; server 400'd at 8192;
jcode's max_retries=8 plus swarm fan-out turned each miss into a flood.

The registry (`automation/config/unsloth-contexts.tsv`) shared the same
measurement error: `server_observed` rows of 8192/30976 recorded whatever
`-c` the studio launched with that day — not a property of the quants.

## Quant audit (the operator's "check the specific quantizations")

Parsed the GGUF header metadata (`<arch>.context_length`) of every quant
file behind the 13-model studio catalog
(`~/.cache/huggingface/hub/models--*`): **all 14 files carry
context_length=262144** (qwen35 / qwen35moe / gemma4 architectures —
including Ornith-1.0-9B-UD-Q4_K_XL, the exact file the flood-era server
launched with 8192). Live proof: the currently loaded
Ornith-1.0-35B-UD-Q2_K_XL serves n_ctx=262144 via `/props`.

The models were always capable of 262144. The "observed" ceilings were
launch-time artifacts.

## Fixes landed (repo)

`automation/lib/model.sh` (gate-green commit this date):

- `unsloth_load_ctx` clamps the pin to the registry `server_observed`
  window and **fails closed** on a pin miss (breadcrumb + skip the leg;
  echoing `000`). The old fail-open behavior let a missed pin fall into an
  unpinned auto-fit load — the 2026-09-22 VRAM-crash class.
- `unsloth_chat` invalidates the 10-minute context-guard cache on
  `exceed_context_size_error` so the next call re-probes and the chain
  falls to the next backend.

Tests: `automation/tests/test-model-loadctx.sh` (fail-closed + clamp
cases), `automation/tests/test-unsloth-context-guard.sh` (exceed case:
invalidate, re-probe, recover). Chain semantics: `$MODEL` is attempted
twice per call on failure (primary + fallback loop), so per-call invalidation
breadcrumbs and probes count 2, not 1.

## Data corrections (machine-local, not committed)

- `automation/config/unsloth-contexts.tsv`: `server_observed` rewritten
  from GGUF metadata for all 13 catalog models = 262144, provenance noted
  per row (`gguf-meta context_length=262144, <quantfile>`), checked_at
  2026-10-04. Non-catalog historical rows left untouched.
- `~/.jcode/config.toml` (backups: `bak-pre-ctx-windows-20261004`,
  `bak-pre-catalog-mirror-20261004`): unsloth model list mirrored to the
  real catalog — 13 entries, all `context_window = 262144`. Dropped 5
  phantom IDs not present in the studio (DavidAU Cold-Fusion-GAIN-V1.1,
  HauhauCS, JonathanColetti, NANI K2-Horizon, XHToken Spark); added 6
  undeclared catalog models (Ornith-1.0-35B, bartowski Qwen3.8-27B,
  gemma-4-12b-it-qat, prism-ml Ternary-Bonsai-27B, mradermacher
  Ornith-1.5-9B-uncensored, dealignai Bonsai-2-27B-Ternary-CRACK).

## Effect

Real-world smoke: 0 `exceed_context_size_error` since 16:47 local (covers
the 17:07 burst window; healthy 200 traffic flowing). If the operator again
launches the server with a small `-c`, 400s can return — but hngh legs now
detect-and-fallback instead of grinding, and the served window is visible
in `/v1/models` `context_length` and the studio UI.

## Open observations

- `nvidia-smi` cannot reach the NVIDIA driver (userspace/driver mismatch
  suspected) while llama-server logs projector-on-CPU "does not fit in
  VRAM alongside" — GPU state needs operator eyes; inference currently
  serves 200s regardless.
- Dynamic VRAM-aware pin sizing (compute the safe window from free VRAM at
  load) remains the follow-up lane; with the desktop up, pins stay at
  16384/32768 (2026-09-22 guard).
