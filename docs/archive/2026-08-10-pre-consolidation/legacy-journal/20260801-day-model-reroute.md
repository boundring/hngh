# 2026-08-01 — Day session: model reroute + day-tasks setup

## Trigger
OpenAI cut GPT-5.6 prices: Luna -80% ($0.10/$0.60 per M tok), Terra -20% ($1/$6).
Kimi K3 (openrouter) intermittently stalling mid-stream (no error -> no retry).

## Changes applied (this session, attended)
- Hermes main model: kimi-k3 -> openai/gpt-5.6-terra (balanced; kimi kept as 1st fallback for design forks)
- Hermes openrouter request_timeout_seconds: 120 (converts silent stream-stall into a retryable error;
  local_stream_stale_timeout default was 900s = 15min hang)
- Hermes fallback chain: kimi-k3 -> glm-5.2 -> qwen3.7-max -> unsloth/gemma-4-12b (local $0)
- Hermes auxiliary bulk slots -> gpt-5.6-luna (cheaper AND smarter than gpt-5.4-nano):
  approval, mcp, title_generation, tts_audio_tags, monitor, skills_hub
- Hermes auxiliary design slots -> glm-5.2: triage_specifier, kanban_decomposer, curator
- Hermes delegation.model stays glm-5.2 (design-tier subagent default)
- omo (oh-my-openagent): CORRECTED per maintainer agent-model-matching.md (2026-07).
  GPT-native deep specialists need SOL not luna (luna too light for deep/ultrabrain):
    hephaestus->sol(medium), oracle->sol(xhigh), deep->sol(high), ultrabrain->sol(xhigh)
  momus->terra(high) [maintainer default], unspecified-high->terra(high)
  unspecified-low->luna(medium) [luna sanctioned here + quick/explore/librarian]
  sisyphus/prometheus/metis/atlas UNCHANGED (kimi-k3/glm-5.2 claude-family, verified)
  metis fallback->deepseek-v4-flash (dropped claude-opus-4-7/gpt-5.5)
  glm-5.2 inserted as design fallback in momus/oracle/deep/ultrabrain
  backup: ~/.config/opencode/oh-my-openagent.json.bak.20260801
  NOTE: initial pass moved deep agents to luna — WRONG, reverted. Luna is for utility/speed only.

## Balances (2026-08-01)
OpenRouter ~$40 (was $41.12), OpenAI ~$40, Anthropic $33, Gemini $41, Zen $25

## Next (day tasks)
- Restart Hermes session to pick up new model/timeout
- Hierarchical delegation chain: terra (manager) -> glm/luna (dept) -> local 12B/Qwythos (workers, $0, queued+guard-railed)
- hngh roadmap: M1 in progress (12/15 deliverables); M7 wire-protocol ADR drafted overnight
- Cost-opt: keep tool bursts compact; condense to small token sets for cheap-model expansion

## Attribution
Config reroute + verification — Hermes TUI (openai/gpt-5.6-terra via openrouter, attended)
Overnight artifacts — night-ralph loop (unsloth/gemma-4-12b-it-qat-GGUF, $0)
