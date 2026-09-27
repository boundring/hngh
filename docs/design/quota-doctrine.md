# Quota doctrine — provider distribution and pacing (2026-09-27)

One chokepoint (`model_call`, `automation/lib/model.sh`), one telemetry
stream (`kind=model` rows in `~/.hngh/db/telemetry.db`), procedural
pacers checked per call. No lane blocks on quota state: a pace-blocked
leg defers to the next leg with a breadcrumb (research never blocks).

## Distribution doctrine

| Tier | Provider / model | Role |
|---|---|---|
| Majority workhorse | zai (GLM-5.3-Flash) | The big bucket: beats, synthesis, review traffic. Rate-controlled, not scarcity-controlled. |
| Secondary bursts | opencode (GLM T2), kimi | Named-cap bursts for overflow and pinned lanes, inside their caps. |
| Long one-shot | xiaomi (mimo-v2.6-pro) | Long completions: news articles, ghost counsel. NOT billion-context sessions — the token-plan gateway is a quota bucket, not a context engine. |
| Burst-limited | gemini (openrouter) | The 20/hour burst gate only; never a default leg. |
| Local | unsloth / ollama / deck | Free legs; local-first for operator-adjacent beats (Jev beat-skip gate decides machine-usage). |

The unpinned-tail ladder (model.sh:1185, 2026-09-24 ops fold) encodes
the paid order: `zai -> xiaomi -> ocgo -> kimi -> remote -> ollama ->
deck` — zai first among paid, local chain ahead of it for local-first
beats. Pins (`MODEL_PIN`) keep their dedicated lanes.

## Cap table

| Provider | Env key | cadence-params rows | Window | Reset |
|---|---|---|---|---|
| zai | `Z_AI_API_KEY` | `zai-cap-5h` 300, `zai-cap-week` 1500 | 5h rolling grid + Monday-UTC week | grid/week boundaries |
| kimi | `KIMI_AI_KEY` / key file | `kimi-daily-cap` 40 | UTC day (hard + soft pace) | 00:00 UTC |
| xiaomi | `XIAOMI_AI_API_KEY` / `~/.config/hngh/xiaomi-key` (600) | `xiaomi-cap-day` 40 | UTC day (hard + soft pace) | 00:00 UTC |
| opencode | `OPENCODE_API_KEY` | opencode caps (60/150/300) | hour/5h/day shapes | per row |
| gemini | openrouter key | `gemini-burst-max-calls` 20 / 3600s | rolling 3600s | sliding |
| remote (unpinned/feedback) | openrouter key | remote caps | shared day cap | 00:00 UTC |

## Pacing mechanics

- `quota_pace_blocked <source> <cap>` (model.sh:531): counts the
  source's telemetry rows for the UTC day; blocks when
  `used >= cap` (hard) or `used > cap*elapsed/86400 + 1` (soft pace,
  one call of grace). Bad/missing cap = fail open (leg runs; a
  misconfigured cap must not take a provider down).
- Pacer visibility requires telemetry: each chat leg emits
  `kind=model` on success. `xiaomi_chat` emits internally (slice 5,
  2026-09-27) so direct callers — the ghost-counsel bridge — are
  paced; `_xiaomi_leg` adds only `MODEL_USED` bookkeeping.
- Ghost counsel adds its own 6 calls/24h stamp cap on top
  (`automation/lib/ghost-voices.py`) — a consumer-side budget, not a
  provider one.

## Reset semantics

UTC-day caps reset at 00:00 UTC (conservative, clock-verified — no
provider reset timezone is guessed). The zai week resets Monday 00:00
UTC. The ocgo 5h grid floors epoch to 18000s (the subscription's true
reset origin is operator-side and unknowable here; grid alignment just
spreads spend, which is the point).
