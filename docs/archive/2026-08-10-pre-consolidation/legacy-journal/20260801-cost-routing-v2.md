# 2026-08-01 — Evening: cost routing v2 (faucet ladder)

## Trigger
Kimi for Code annual subscription active (replaces Moderato monthly, paid
through next year). Directive: exploit free faucets first, distribute quota'd
subscriptions across their reset windows, sprinkle local $0, spend payg last.
OpenRouter lifetime spend $562.56 — cost optimization is now the priority.

## Verified live (this session, attended)
- `api.kimi.com/coding` serves exactly: k3, k3-256k, kimi-for-coding (K2.7),
  kimi-for-coding-highspeed. K2.6 is NOT on the subscription endpoint.
- GitHub Copilot via `gh` token serves 36 models incl. claude-sonnet-5,
  claude-opus-5/4.8, gemini-3.6-flash, gpt-5.6-terra/sol/luna, gpt-5.5.
- Gemini AI Studio key lists gemini-3.5-flash, 3.5-flash-lite, 3.1-flash-lite
  (free tier).
- OpenRouter has 14 `:free` models; best: nemotron-3-ultra-550b (1M ctx),
  cohere/north-mini-code, gemma-4-31b, ling-3.0-flash.
- xAI is dead: "team doesn't have any credits or licenses."
- opencode auth: google (AI Studio key), kimi-for-coding, xai only; openai
  models resolve via session env (plasma-workspace/env/env_vars.sh).

## Changes applied (attended)
- Hermes `fallback_providers`: k3 → kimi-for-coding (K2.7) → nemotron:free →
  north-mini-code:free → copilot/claude-sonnet-5 → gemini/3.5-flash → luna →
  glm-5.2 → local gemma-4-12b.
- Hermes vision aux: openrouter/kimi-k2.6 (payg) → kimi-coding/k3, fallback
  gemini/3.5-flash.
- Hermes MoA (preset + top-level): openrouter/kimi-k3 → kimi-coding/k3;
  openrouter/deepseek-v4-pro → copilot/claude-sonnet-5 (antagonistic-review
  fanout on quota, not payg); aggregator glm-5.2 → kimi-coding/k3.
- Hermes compression aux: openrouter/glm-5.2 → gemini/3.5-flash (free tier).
- OMO multimodal-looker: openrouter/kimi-k2.6 → kimi-for-coding/k3 (vision
  on quota).
- OMO background_task concurrency key: openrouter/kimi-k2.7-code →
  kimi-for-coding/kimi-for-coding.
- Unchanged: luna bulk aux slots ($0.10/M — cheaper than burning sub quota on
  title-gen); glm-5.2 design aux (infrequent); zen fallbacks (slow drain);
  momus/oracle/deep/ultrabrain on terra/sol.
- Backups: config.yaml.bak.20260801_193400, oh-my-openagent.json.bak.20260801_193400.
- `docs/design/model-routing.md` route table replaced with the verified
  faucet ladder; fallback chains updated; xAI marked dead.

## Balances (unchanged this session)
OpenRouter ~$40, OpenAI ~$40, Anthropic $33, Gemini $41, Zen $25.

## Next
- Restart Hermes session to activate fallback/vision/compression changes
  (main+delegation were already kimi-coding/k3).
- `opencode auth login` GitHub Copilot → unlock claude/gemini-3.6-flash quota
  inside opencode, then add copilot fallbacks to sisyphus/prometheus chains.
- Run Queue A 1–6 (day-tasks journal) as first live test of the new ladder.
- Weekly quota/balance audit vs routing table drift (candidate cron).
- H-D3: fold this ladder into M8 route-table data (`src/plugins/model-routes.lisp`).

## Attribution
Faucet verification + config reroute + docs — Hermes TUI (kimi-coding/k3,
attended). Plan: `sysconfig_mgmt/.hermes/plans/2026-08-01_194000-cost-routing-v2.md`.
