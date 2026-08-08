# 20260805 — Model mandate applied to squads

## What

Aligned hngh squad model selections to the canonical chain now enforced in
`~/.config/opencode/oh-my-openagent.json` + `~/.hermes/config.yaml`:
deepseek-v4-flash-0731 (openrouter) primary for most purposes; GLM-5.2 deep
tier; qwen3.7-flash vision looker; free/local models as last-resort fallbacks.

## Changes

- **squad-seats.conf**: PM/Designer glm-5.2; Coder/Artist/Accountant/Worker
  deepseek-v4-flash-0731; canonical fallback chains per seat; Artist vision
  looker qwen3.7-flash; kimi-k2.6 / deepseek-v4-pro / gemini-lite assignments
  removed.
- **squad-up** (launcher): default table + ROLE-ACK prompts + `--cheap` fallback
  moved off k3 / local gemma / v4-pro to the mandate.
- **squad-seats-cheap.conf**: all seats deepseek-v4-flash-0731 (accountant no
  longer gemini-lite).
- **AGENTS.md**: local-model policy rewritten remote-first; Copilot reliance
  removed per user correction; MCP section += nothumansearch, optmem-replacement
  design note.
- **model-pareto.md**: + deepseek-v4-flash-0731 row (footnote: verify price);
  per-role table + example cost block updated; Artist note -> qwen3.7-flash
  looker; gpt-5.6-luna provider openai.
- **model-routing.md**: 2026-08-05 mandate blockquote; + `or-dsv4` route; live
  Hermes fallback chain updated to config mirror.
- **model-strategy.md**: PM rotation matrix, Skeleton/Bones/Fan-out drivers ->
  deepseek-v4-flash-0731; MisakaNet pre-flight now uses misakanet MCP; luna
  provider openai.

## Open

- **Code-embedded models (implementation wave — still old chain):**
  - `src/plugins/hngh-up.lisp:183-185` strategy option labels,
    `:255-262` strategy model tables (local-only gemma / budget-50
    kimi-k2.6+deepseek-v4-flash / budget-200 kimi-k3+gpt-5.6-luna).
  - `src/plugins/ai-tool-hub.lisp:635` opencode default `-m`
    gemma-4-12b; `:696` `:local-openai-api` gemma-4-12b.
  - `src/plugins/squad-resources.lisp:17-24` resource keys (mostly
    harmless keys; kimi entries stale).
  - Update code + prompt-matrix.md together (keep doc-code in sync),
    with tests, via make test gate.
- OptMem -> cogmem/misakanet for PM communication: design review before change
  (touches coordination contract in AGENTS.md + 14 docs).
  [2026-08-07: cogmem DROPPED — see ADR-042; only misakanet remains a candidate.]
- Verify deepseek-v4-flash-0731 price on OpenRouter catalog (footnote \*).
- Remaining docs with model refs (prompt-matrix, projected-design-sessions,
  squad-metabolism, dispatch-tree, hngh-up, mission-control, agent-platoons,
  local-model-benchmarks, beans-lifecycle, file-watcher, next.md,
  work-sessions.md): low-priority churn; update as encountered — but keep
  in sync with the code wave above.

Attribution: model mandate review — deepseek-v4-flash-0731 via openrouter
(Hermes TUI).
