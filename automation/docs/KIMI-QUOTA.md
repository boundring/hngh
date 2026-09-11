# Kimi quota matrix (2026-09-07)

Systematic (key, endpoint, model) probe, one variable at a time. Key names
only; values never printed. Each row: HTTP status + first error field of the
response body.

## Matrix

Endpoints probed per key: `api.moonshot.ai/v1` (models + chat),
`api.moonshot.cn/v1` (models), `api.kimi.com/v1` (models + chat),
`api.kimi.com/coding/v1` (models + chat, OpenAI shape),
`api.kimi.com/coding/v1/messages` (anthropic shape), `api.moonshot.cn/anthropic/v1/messages`.

| key | api.moonshot.ai/v1 | api.moonshot.cn/v1 | api.kimi.com/v1 | api.kimi.com/coding/v1 |
|---|---|---|---|---|
| MOONSHOTAI_API_KEY (51 chars) | 200 models `kimi-k2.7-code,kimi-k2.6`; chat 429 `exceeded_current_quota_error` | 401 `Invalid Authentication` | 404 (no resource) | 401 `invalid_authentication_error` |
| KIMI_AI_KEY (72 chars) | 401 `Invalid Authentication` | 401 `Invalid Authentication` | 404 (no resource) | **200 models** `kimi-for-coding, kimi-for-coding-highspeed, k3-256k, k3`; chat **200** with completion (see notes) |
| KIMI_FOR_CODING_KEY (72 chars) | 401 `Invalid Authentication` | 401 `Invalid Authentication` | 404 (no resource) | **200 models** same list; chat **200** |

Anthropic-style shapes: `POST api.kimi.com/coding/v1/messages` with
`x-api-key` + `anthropic-version` is reachable but a minimal request returns
HTTP 200 whose body is `Error: cannot use null as iterable (array or
object)` — it expects Claude-Code-shaped payloads (per the official Claude
Code integration doc, `ANTHROPIC_BASE_URL=https://api.kimi.com/coding/`
works for Claude Code itself). Not a raw URL we need; dropped.
`api.moonshot.cn/anthropic/v1/messages` -> 401 `invalid_authentication_error`.

## Diagnosis

- The **K3 quota is the kimi.com consumer Kimi Code plan**, not the Moonshot
  open platform. Per the official docs (kimi.com/code/docs, "Claude Code"
  page): K3 requires a Kimi membership with Kimi Code benefits activated;
  keys are created in the Kimi Code Console; the endpoint is
  `https://api.kimi.com/coding/` with models `k3`, `k3-256k`,
  `kimi-for-coding`, `kimi-for-coding-highspeed` (K3 needs Moderato or
  above). Both 72-char env keys (KIMI_AI_KEY, KIMI_FOR_CODING_KEY) validate
  and complete there.
- **Why MOONSHOTAI_API_KEY 429s**: it authenticates cleanly on
  api.moonshot.ai and lists `kimi-k2.7-code,kimi-k2.6`, but chat returns 429
  `exceeded_current_quota_error` — a platform account with no balance.
  Recharge happens at platform.moonshot.ai; that is a PAYMENT action, which
  the operator must decide on and perform. Hngh never does it. No K3 model
  exists on the platform endpoint, so recharging would only buy K2.6/K2.7.
- **KIMI_AI_KEY works** — on the Kimi Code endpoint. The operator's statement
  "our K3 quota will be via our KIMI_AI_KEY environment variable key" is
  consistent with the matrix: it is the consumer-plan key. KIMI_FOR_CODING_KEY
  behaves identically (likely a second console key on the same plan).

## Gotchas verified live

- The coding gateway **rejects request bursts** with HTTP 400
  `Invalid request Error` / `Error: cannot use null as iterable (array or
  object)`. Single spaced requests return 200. This looks like undocumented
  per-minute throttling; kimi_chat's single-call-per-leg pattern is safe, but
  tight retry loops against this endpoint will read throttling as a bad
  request.
- Coding models are **thinking-only** (`supports_thinking_type: "only"`):
  reasoning tokens count against `max_tokens`. A 32-token budget returns
  empty `content` with `finish_reason: "length"`; ~60+ completion tokens were
  needed for a one-word reply (29-47 reasoning tokens on `kimi-for-coding`).
- The coding gateway **rejects `temperature`** with HTTP 400 `Invalid request
  Error` / `Error: cannot use null as iterable (array or object)` (verified:
  body with `temperature: 0.3` -> 400, same body without it -> 200;
  `chat_template_kwargs` is accepted and ignored). `kimi_chat` now sends a
  lean body (model/messages/max_tokens only) via `_kimi_body`.
- `max_tokens` and `max_completion_tokens` are both accepted; streaming
  (`stream: true`) and non-streaming both work.

## Landed

- `lib/model.sh` MODEL_PIN routing (2026-09-07, operator quota directive):
  quota models are intelligence primaries for bounded work, not
  last-resort fallbacks. Which cycles pin where and why:

  | MODEL_PIN | chain | pinned by |
  |---|---|---|
  | `local` | unsloth -> ollama only | news, ux-review, bench (low-stakes or probing local models) |
  | `kimi` | kimi -> unsloth -> ollama -> deck -> archive; remote + lobehub skipped | research beat every Nth run (`kimi-research-share`, default 3); research REVIEW transition always; fresh-eyes review (`04-review-prep.sh`) always |
  | `deck` | deck -> unsloth -> ollama -> kimi -> archive; remote + lobehub skipped | (available for second-server overflow; no cycle pins it yet) |
| `lobehub` | lobehub (Responses API) -> unsloth -> ollama -> deck -> archive; remote + kimi skipped | research volume, every 6th beat (`lobehub-research-share`, demoted to 0 / opportunistic 2026-09-11 per docs/research/2026-09-10-lobehub-worth-it.md s3; re-arm = flip row nonzero) |
  | anything else | full chain, remote/openrouter last | delegated sessions (budget-gated) |

  Research rotation: 1 beat/hour, every 3rd run on kimi = <=8 kimi
  calls/day against the 40/day cap, distributed across the quota window
  by the run counter + quota_pace_blocked. A pace-blocked or 429ing kimi
  falls through to the local chain inside model_call — research and
  reviews never block on quota state, and local is never blocked by kimi
  state. The review-prep "model chain down" alert is chain-accurate:
  it fires only when the whole pinned chain (kimi -> unsloth -> ollama)
  has failed.
- `lib/model.sh` `kimi_chat`: default URL is now the Kimi Code
  chat-completions endpoint; key order KIMI_AI_KEY -> KIMI_FOR_CODING_KEY ->
  MOONSHOTAI_API_KEY -> key file.
- `config.env` stopgap: `KIMI_URL` + `KIMI_MODEL=k3-256k` (k3-256k delivers
  the same result as 1M `k3` at roughly half the quota burn per the docs).

## Operator question (open)

Which plan tier holds the K3 quota — confirm the Kimi membership tier
(Moderato+ for `k3`/`k3-256k`) in the Kimi Code Console
(kimi.com/code/console), and whether the Moonshot platform account
(MOONSHOTAI_API_KEY, 429 no-balance) should be recharged at
platform.moonshot.ai or left dead. Recharge is a payment: operator-only.
