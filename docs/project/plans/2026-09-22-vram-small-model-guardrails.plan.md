<!-- plan: status=executing risk=normal accepted=2026-09-23T00:04:17Z -->
# VRAM/RAM guardrails: small-model lane, standardized beat contexts, unit RAM caps

Proposed via `omp-bridge --propose` (omp session propose surface;
see docs/project/plans/README.md).

Execution note (2026-09-22 evening): this session executes the steps
directly (omp plan approval maps onto this contract, plans/README.md
"omp plugin interface"); status=executing keeps the overnight cycle off
an in-flight plan. Full step text lives in the executed session's plan;
the steps below are the same five.

## Steps

- [ ] Step 1 — pin every Unsloth load to a standardized context
  (`lib/model.sh` `unsloth_load_ctx` on the `unsloth_attempt` funnel;
  `ctx-standard` 16384 / `ctx-deep` 32768 rows; per-class `MODEL_CTX`
  exports in 04-review-prep.sh, 33-research-beat.sh plan synth,
  automation/scripts/overnight-cycle.sh; model-bench.sh coverage).
- [x] Step 2 — small-model lane (config.env `MODEL`
  unsloth/Ornith-1.0-9B-GGUF, `UNSLOTH_FALLBACK_MODELS`
  unsloth/gemma-4-12b-it-qat-GGUF, `BENCH_MODELS` small-first;
  automation/README.md defaults + tier line) — 2026-09-22 evening.
- [ ] Step 2b — quota fallback tier after local (`xiaomi_chat` /
  `_xiaomi_leg` on xiaomi-endpoint/xiaomi-model rows; opencode leg
  re-armed; unpinned tail reordered zai -> xiaomi -> ocgo -> kimi ->
  remote -> ollama -> deck -> archive-only).
- [x] Step 3 — anti-runaway RAM caps on the 10 cadence/automation units
  (`~/.config/systemd/user/<unit>.service.d/mem-caps.conf`,
  MemoryHigh/MemoryMax per the measured-peak table; verified byte
  values) — 2026-09-22 evening.
- [ ] Step 4 — correct the crash brief trigger chain + the OOM
  prevention handoff queue (bounded-context landing, Ternary Bonsai
  activation path).

Verification: see plans/README verification contract; automation
`make test` green at landing plus this plan's live checks (bounded-
context load via /api/inference/load `max_seq_length`, unit caps byte
values, quota-tier routing with local legs made to miss).
