# 2026-09-22 — VRAM/RAM guardrails: context-pinned loads, small-model lane, quota tier, unit caps

Status: landed. Plan
`docs/project/plans/2026-09-22-vram-small-model-guardrails.plan.md`
(executed directly by the 2026-09-22 evening omp session, operator
approval on the plan; automation/ free-commit surface, kernel untouched).

## Context

Two Plasma session losses (2026-09-20 17:25, 2026-09-22 09:04) were
amdgpu command-submission exhaustion: an Unsloth auto-load filled VRAM
to zero desktop headroom (09:03:10 load = 20.5 GB: 9.2 GB GGUF + 0.9 GB
mmproj + 8.4 GB KV at context 127488, into 20420 MiB free) and Mesa
aborted Xorg (brief:
docs/agent-notes/briefs/2026-09-22-plasma-crash-gpu-memory-exhaustion.md,
trigger-chain refinement landed with this slice). Operator asks: tone
down the RAM/VRAM the cadence beats ask for (small models — Ornith 9B /
Ternary Bonsai steer), standardize the context length per beat class so
loads request only the context the beat needs, and put the quota legs
(Z.AI, Xiaomi AI, OpenCode, Kimi) in as the fallback tier after the
local models.

## Changes

1. Context pin (Step 1): `lib/model.sh` `unsloth_load_ctx` posts
   `POST /api/inference/load` with `max_seq_length` before every
   `unsloth_attempt` (the single local-load funnel), so the studio
   fitter sizes the window to the beat budget instead of filling free
   VRAM. Rows `ctx-standard` 16384 / `ctx-deep` 32768 (env `MODEL_CTX`
   overrides); deep tier exported at `cadence/day/04-review-prep.sh`,
   the plan-synth call in `cadence/hour/33-research-beat.sh`, and both
   `model_call 4096` sites in `automation/scripts/overnight-cycle.sh`.
   Pin failures are fail-open (breadcrumb `load-ctx ... continuing
   unpinned`, beat proceeds); `HNGH_LOADCTX_PIN=0` is the hermetic-test
   seam (no /load POST at all).
2. Small-model lane (Step 2): `config.env` `MODEL`
   unsloth/Ornith-1.0-9B-GGUF (was the 27B crash load),
   `UNSLOTH_FALLBACK_MODELS` unsloth/gemma-4-12b-it-qat-GGUF only,
   `BENCH_MODELS` same 7-model catalog small-first; README model-chain
   list + context-tier line updated (incl. a pre-existing stale Ollama
   default corrected).
3. Quota fallback tier (Step 2b): new `xiaomi_chat` / `_xiaomi_leg`
   (rows `xiaomi-endpoint` https://token-plan-sgp.xiaomimimo.com/v1/chat/completions,
   `xiaomi-model` mimo-v2.6-pro; key = `XIAOMI_AI_API_KEY` env else the
   `XIAOMI_KEY_FILE` 0600 file; empty row/key skips fail-closed). The
   OpenCode leg is re-armed from its rows' own documented pre-disable
   values (url `https://opencode.ai/zen/go/v1/chat/completions`, model
   glm-5.3-flash, caps 5h 60 / 7d 150 / month 300). Unpinned tail
   reordered quota-first: zai -> xiaomi -> ocgo -> kimi -> remote ->
   ollama -> deck -> archive-only (blocks moved with guards verbatim;
   pinned lanes and the pin_review ladder untouched).
4. Unit RAM caps (Step 3, machine state): `mem-caps.conf` drop-ins on
   the 10 cadence/automation units (MemoryHigh = 1.5x observed
   MemoryPeak rounded to 128M, MemoryMax = 4x rounded to 256M —
   anti-runaway; session-spawning units and the already-capped
   dashboard/unsloth-studio excluded).
5. Records (Step 4): crash brief gained `## Trigger chain (refined
   2026-09-22 evening session)` and an amended hngh-impact verdict
   (hngh was a contributing trigger); the OOM handoff's open "VRAM half
   of 5b" now records the landing and the Ternary Bonsai activation
   path.

## Verification

New hermetic suite `tests/test-model-loadctx.sh` (written first, red,
then green): load body carries the ctx row's value, non-200 pin is
fail-open with the unpinned breadcrumb, `HNGH_LOADCTX_PIN=0` posts
nothing, `MODEL_CTX` env beats the row, xiaomi skips fail-closed
without a key and serves with a stub (MODEL_USED=xiaomi:mimo-v2.6-pro),
and no bearer/key value rides any argv. Chain suites
(test-model-pin-routing.sh, test-model-reply-scrub.sh,
test-bench-trigger.sh, test-memory-gate.sh) green. Full automation gate
(`make test`) green at landing. Live checks: `MODEL_CTX=8192` beat-shaped
call -> `/api/inference/status` `requested_context_length` 8192 and
`context_length` <= 8192, `rocm-smi` VRAM used <= 10 GB with >= 9 GB
free (vs 20.5 GB of 20420 MiB free at the crash); repeat at 16384 with
no reload; unit caps byte values match the plan table via `systemctl
--user show`; with the local legs made to miss, the chain lands on a
quota leg when armed.

## Notes

- Integration catches from the first gate run: `config/leg-budgets.tsv`
  gained the `xiaomi` chain-leg row (the leg-budgets guard reds any
  chain leg without a registry row), `tests/test-model-pin-routing.sh`
  gained the one-line `HNGH_LOADCTX_PIN=0` seam (its stub POST counter
  saw the extra /load call), `tests/test-probe-hygiene.sh`'s model.sh
  Bearer-directive tripwire moved 4 -> 5 (the pin is a legitimate fifth
  stdin-config site, same hygiene shape), and the research plan-synth `MODEL_CTX` is
  scoped to that one `model_call` (a process-wide export would have
  pushed the beat's later calls onto the deep tier).
- OpenCode caps are the rows' own documented history (60/150/300), not
  invented values; `opencode-research-share` deliberately stays 0 —
  the operator directive covers the fallback tier only, and the
  research-run rotation pin stays off for quota conservation (row note
  reworded away from the retired "dead leg" wording).
- `unsloth_load_ctx` sends the pin even when the token file is empty
  (empty bearer -> 401 -> fail-open path); fail-open is the design.
- Studio-side fit policy (it sizes a load to fill free VRAM unless
  `max_seq_length` is sent) and the two upstream reports (Mesa aborting
  all of X on one BO-alloc failure; plasmalogin greeter no-retry /
  no-software-fallback) remain operator items per the crash brief.
- Ternary Bonsai deferred: HF cache holds repo metadata only; activation
  = `hf download prism-ml/Ternary-Bonsai-2-27B-gguf`, confirm the served
  id on GET /v1/models, prepend to `UNSLOTH_FALLBACK_MODELS`.
