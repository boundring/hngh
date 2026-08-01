# Model Routing (M8 seed) — design

Status: seed design, 2026-07-31. Author: moonshotai/kimi-k3 via OpenRouter
(Hermes TUI). Design influence: evey-setup (LiteLLM router pattern, attributed
below); hngh M2 (configurable baseURL) + M4 (model-runtime) provide the
substrate.

## Problem

Today each caller picks a model ad hoc: the task driver hard-prefers
`:local-openai-api` (unsloth :8888), Hermes/opencode pick per-flag, and cost
control is a separate sidecar (`llm-budget`). There is no single place that
says "for this class of work, use this model, at this budget, falling back to
that one." M8 (model-management plugin) needs that place.

## Pattern cribbed: the single routing proxy (evey-setup / LiteLLM)

evey-setup runs 24/7 at ~$0 by putting ONE proxy (LiteLLM, :4000) in front of
all backends and giving it: named routes, per-route budgets, and a fallback
chain. We adopt the *pattern*, not the Docker stack:

- **One router** between callers and backends. Callers name a *route*, not a
  model. The router owns model selection.
- **Budget per route** — each route carries a spend cap + a window; the
  router refuses or degrades when a route is over. Hook: `llm-budget`
  (rolling 60-min OpenRouter spend) for remote routes; local routes are
  exempt ($0 by construction).
- **Fallback chain** — a route lists alternates in preference order; the
  router walks down on unavailability (health check) or budget exhaustion.

We do NOT run LiteLLM itself. hngh already has the pieces: model-runtime
(spawn/health/unload for ollama + llama.cpp + unsloth-API), the tool hub
(`*provider-endpoints*`, rebindable), and the task driver (policy
`(:prefer-tool ...)`). M8 adds the routing table + selection logic in Lisp.

## Routes (verified faucet ladder, 2026-08-01 v2)

Cost ladder: free faucets first, quota'd subscriptions second, local $0
sprinkles, careful pay-as-you-go last. Verified live against each endpoint.

| Route | Backend | Model | $/tok | Use for |
|---|---|---|---|---|
| `local-12b` | ollama :11434 | gemma-4-12B-it-qat (loaded) | $0 | loops, drafts, queue tasks, test-gen |
| `local-long` | unsloth :8888 | Qwythos-9B (1M ctx) | $0 | long-context recon, repo-wide reads |
| `local-heavy` | unsloth :8888 | Qwen3.6-27B / Devstral-24B | $0 | hard local coding (VRAM-permitting) |
| `or-free` | openrouter | nemotron-3-ultra-550b (1M ctx), north-mini-code, gemma-4-31b, ling-3.0-flash | $0, rate-limited | bulk remote when local ctx/quality short |
| `gemini-free` | AI Studio key | gemini-3.5-flash / 3.5-flash-lite / 3.1-flash-lite | $0, daily/RPM caps | compression, web extract, light vision |
| `kimi-sub` | api.kimi.com/coding (annual) | k3, k3-256k, kimi-for-coding (K2.7), K2.7-highspeed | $0 marginal, hourly/daily/weekly quota | main agent, delegation, design forks, MoA aggregate |
| `copilot` | api.githubcopilot.com (gh token) | claude-sonnet-5, claude-opus-5, gemini-3.6-flash, gpt-5.6 family | subscription quota | antagonistic review, anthropic-tier w/o Anthropic balance |
| `cheap` | openai-api / openrouter | gpt-5.6-luna, z-ai/glm-5.2 | ~$0.10–$0.60/M | bulk aux (title, approval, mcp), design-tier aux |
| `frontier` | openai-api / openrouter | gpt-5.6-terra/sol | $1–$6/M | architecture forks, novel debugging only |
| `zen-drain` | opencode zen | gpt-5.6-luna via zen | balance $25 | mid-chain fallback only; drain slowly |
| `anthropic` | anthropic direct | claude (rare) | balance $33 | rare use cases only; copilot covers most anthropic-tier needs |

Dead: `xai` — account has no credits/licenses ("newly created team" error
2026-08-01). Re-check if xAI opens a free tier. K2.6 is not on the Kimi for
Coding endpoint; K2.7 (`kimi-for-coding`) replaces it on quota.

Local routes exempt from budget. Remote payg routes carry caps via
`llm-budget`; quota routes (kimi-sub, copilot, gemini-free, or-free) are
rate-limit-gated by the provider, fail over on 429.

## Fallback chains (health + budget driven)

- `local-12b` → `local-heavy` → `or-free` → `gemini-free` → `kimi-sub`
- `or-free` → `local-12b` (rate-limited, degrade to free local)
- `kimi-sub` → `copilot` → `gemini-free` → `cheap` → `local-12b`
- `copilot` → `kimi-sub` (quota) or `anthropic` (rare, balance-gated)
- `frontier` → `kimi-sub` → `copilot`

Live Hermes fallback chain (2026-08-01): k3 → kimi-for-coding (K2.7) →
nemotron-3-ultra:free → north-mini-code:free → claude-sonnet-5 (copilot) →
gemini-3.5-flash (AI Studio) → gpt-5.6-luna → glm-5.2 → local gemma-4-12b.

Health: model-runtime's `health` per backend; unsloth empty (`unsloth: []`)
means "no model resident — route to ollama instead" until warm.

## Selection logic (M8 implementation sketch)

```
(defun route-task (task-class)
  "Return (values tool-id endpoint model) for TASK-CLASS, walking the
class's fallback chain past unhealthy or over-budget routes."
  ...)
```

The task driver's policy `(:prefer-tool :local-openai-api)` becomes
`(:route :local-12b)`; the orchestrator's remote picks become `(:route
:kimi-sub)` / `(:route :copilot)` / `(:route :cheap)`. `llm-budget` is
consulted for payg routes before dispatch (fail-closed: unreachable budget API
= treat as over for payg routes only; local and quota routes unaffected).

## Cost ledger

Per-route counters in the state store, fed by (a) `llm-budget` for remote,
(b) token counts from queue `:result` usage fields for local (informational,
$0). Open question deferred from the program plan: ledger in hngh state store
vs OptMem — leaning state store (per-instance, queryable by the router).

## Non-goals (YAGNI for the seed)

- No Docker/LiteLLM deployment. No Qdrant/RAG. No n8n. No MQTT.
- No per-user routing (single-user fleet for now; M3 "The Network" later).
- No automatic VRAM eviction policy beyond the existing one-resident-model
  constraint (M4.1 note) — a sidecar small model is a later wave.

## Verification for the seed

- This document reviewed against evey-setup's README (pattern attributed).
- The routing table lands as data in the night-run task pack (task #2:
  `src/plugins/model-routes.lisp`, read-only parse test), seeding M8 without
  committing to logic yet.
