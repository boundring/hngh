# Model catalog accommodation (owner 11:15) — design note

Status: items 2+3 SHIPPED 12:10 (Seu, card 107B); item 1 = card 107A
(config root-cause fix, coder lane); item 4 already live as dashboard P2.

How to make the models we actually use first-class in Hermes + Hngh
seat spawns, without fighting the static manifest.

## Ground truth (from hermes source, read 2026-08-09)

`hermes_cli/model_catalog.py`:
- The manifest is FETCHED + CACHED, not read from the repo file. Disk
  cache: `~/.hermes/cache/model_catalog.json`. Fetch URLs:
  `https://hermes-agent.nousresearch.com/docs/api/model-catalog.json`
  with fallback to the raw GitHub URL of the same manifest. TTL 1h,
  SWR-refresh background thread. Editing the website/static file is
  overwritten; NOT the way.
- Config block `model_catalog:` in config.yaml:
  `enabled`, `url` (override whole manifest), `ttl_hours`,
  `providers.<name>.url` (per-provider override manifest). Per-provider
  overrides skip the disk cache (third-party self-hosted friendly).
- Custom providers already work: config `providers.unsloth-local` with
  `discover_models: true` and explicit `models:` list is the existing
  pattern (unsloth GGUF family). The picker merges config providers.
  NOTE: `unsloth-local` is a CONFIG custom provider, NOT a canonical
  slug — verified from hermes_cli/models.py 2026-08-09 (not in
  CANONICAL_PROVIDERS nor _PROVIDER_MODELS). seat-up's gate must read
  config providers to accept it.
- CANONICAL_PROVIDERS (~33): openrouter, nous, openai-api, deepseek,
  anthropic, gemini, kimi-coding(+cn), zai, xai,
  lmstudio, fireworks, moa, novita, nvidia, stepfun, minimax(+variants),
  alibaba, xiaomi, tencent-tokenhub, copilot(+acp), huggingface, vertex,
  etc. (`unsloth-local` is NOT in this list — config custom provider.)

## What we actually use (config.yaml, 2026-08-09)

| Model | Provider | Tier |
|---|---|---|
| deepseek/deepseek-v4-flash-0731 | openrouter | workhorse (default) |
| deepseek-v4-flash | deepseek | workhorse |
| openai/gpt-5.6-luna (+pro) | openrouter / openai-api | **workhorse** (owner 2026-08-09: anything under $0.20/M is a workhorse or candidate) |
| z-ai/glm-5.2 | openrouter | reserve if ≥$0.20/M; else workhorse — price-check |
| xiaomi/mimo-v2.5 | openrouter | workhorse/fallback |
| unsloth/{Qwen-AgentWorld-35B, Ornith variants, gemma-4-12b} | unsloth-local (local HTTP) | local/free |
| moonshotai/kimi-k3 | openrouter/kimi-coding | reserve (quota-windowed; deliberate distribution per window) |

Tier rule (owner 2026-08-09): anything cheaper than ~$0.20/M is a
workhorse or should be considered for it. Strategic reserve = models at
or above the line (currently K3, glm-5.2 pending price check, frontier)
used deliberately, quota-distributed, never idle-unused.

K3 use tactic (owner 2026-08-09): distribute as evenly as possible
across each window (5h / 7d / monthly). Many SMALL strategic calls —
code completions, doc improvements — with HEAVY restrictions on tokens
passed (tiny prompts, tight budgets). Not "one big task": even spread
is what prevents the repeated outcome of quota running out before it
makes a difference.

GENERAL MODEL-CALLING PRINCIPLE (owner 2026-08-09): agents call on
specific models for specific purposes, when needed. Nearly always cheap
workhorses; a call may attach specific limits (token budgets, context
windows), specifications, and instructions to a particular need.
Models are tools in the agent's hands — the routing layer (per-role
roll config, fallback chains, model_catalog providers) should make
"cheap by default, specific by request" the natural shape.

Most of these ARE in the shipped manifest (openrouter + nous carry
luna, luna-pro, flash-0731, k3, glm-5.2, mimo). The gaps are:
1. **unsloth-local family** — not canonical, lives in config `providers:`.
2. **config's bare `provider: openai` entries** (fallback chain lines
   23-24 etc.) — there is NO canonical `openai` provider; the real one
   is `openai-api`. Those entries are the bad spec behind the luna→flash
   saga (documented in dashboard.md P2). They should read
   `provider: openai-api, model: gpt-5.6-luna` (and note: the picker
   uses openrouter for openai-model ids in the current manifest).
3. seat-up's gate validates against the STATIC site file
   (model_catalog.json) which has only openrouter+nous — that's why a
   fresh/openai-api spawn is mis-validated.

## Design (recommendation)

1. **Fix the config fallback chain**: `openai` → `openai-api` in the
   fallback_providers entries (and any other bare-openai references).
   This is the root-cause repair, independent of the catalog. → card
   107A, coder lane.
2. **Make seat-up validate against the RUNTIME truth, not the static
   file**: SHIPPED 2026-08-09 (Seu, 107B). seat-up now defaults to the
   disk cache (`~/.hermes/cache/model_catalog.json`) when present,
   falls back to the checkout copy, and its Python gate merges three
   accept sources: catalog block → CANONICAL_PROVIDERS/_PROVIDER_MODELS
   → config `providers.<name>.models`. Config custom providers
   (unsloth-local) now spawn without a static-catalog entry. The gate
   runs under the Hermes venv python (system python3 lacks yaml).
3. **Add a Hngh-owned "our models" manifest**: SHIPPED 2026-08-09 (Seu,
   107B) — `docs/design/model-manifest.json`, schema v1 (validated
   against `hermes_cli/model_catalog._validate_manifest` in the
   fixture suite). Enumerates our provider:model set with tier
   metadata (workhorse/reserve). Point
   `model_catalog.providers.<name>.url` at it (example:
   `file:///home/bricker/Projects/etc/hngh/docs/design/model-manifest.json`)
   to make these models visible to the Hermes picker; `file://`
   transport verified working (urllib).
4. **pin models per role**: the spawn-time fail-closed rule (dashboard
   P2) — a seat requests an explicit provider:model and either gets it
   or stops; fallback chains per role come from the manifest, never
   silently. Already live in seat-up.

## Owner decision needed
- Items 2+3 SHIPPED (107B); item 1 pending owner go (config fallback
  chain fix, 107A): flip `openai` → `openai-api` in fallback_providers.
- For luna seats: `openai-api` (owner preference) vs `openrouter`
  (current manifest listing). openai-api is canonical; if the API key
  (OPENAI_API_KEY?) is present, prefer it per owner's message. Both are
  enumerated in model-manifest.json.
- Whether to also refresh `~/.hermes/cache/model_catalog.json` once via
  `hermes model --refresh` (pulls the current published manifest) so the
  picker/seat-up see today's models — optional; the cache is
  SWR-refreshed on its own anyway.
- Whether to wire `model_catalog.providers.<n>.url` to the manifest
  file (makes our ids visible to the Hermes picker directly; works but
  not strictly needed while config providers + cache already cover
  spawning).

Attribution: Sanakan (deepseek-v4-flash-0731), hermes TUI, 2026-08-09 —
researched from hermes source; pending owner confirmation; Seu/Cibo may
act on 1+2 when the owner says go.