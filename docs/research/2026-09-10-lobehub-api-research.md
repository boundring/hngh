# LobeHub API Research - Quota Consumption Pathways (2026-09-10)

## 1. Local Trace: Pi-to-LobeHub Connection

**Finding: No direct local connection between Pi and LobeHub.**

Config files examined: ~/.config/pi*, ~/.pi/, ~/.config/billion-context/*, ~/.config/fish/functions/pi.fish, ~/.config/plasma-workspace/env/env_vars.sh, ss output.

| File | Lobehub reference? | What exists instead |
|------|-------------------|---------------------|
| env_vars.sh | No LOBEHUB base_url or endpoint | OPENCODE_API_KEY=sk-7ZXCD0EaEXvm38X26BhBQqA2QcVE0tUEauPjpX4Uf5vPKXOOhel27nI7gSx3vdxb (separate from OPENROUTER_API_KEY=REDACTED) |
| models-store.json | No lobehub provider entry | Pi connects to OpenCode Go for GLM-5.x via opencode.ai/zen/go/v1/chat/completions |
| billion-context.json | providers={} (empty) | Only compress settings present; no provider mappings |
| pi.fish | "command bili pi -- $argv" | Shell wrapper around bili proxy |
| TCP listeners | Only syncthing on localhost:8081 | No LobeHub server listening anywhere |

Pi does NOT connect to LobeHub as a provider. Pi connects to **OpenCode Go** (operator-subscribed 2026-09-10 at opencode.ai/zen/go/v1/chat/completions) for GLM-5 models. Same OPENCODE_API_KEY feeds both Pi and the Hngh OpenCode Go quota leg; verified working via bounded POST returning HTTP 200-completed (hngh-agent b367b0c/2bc5da8). This is the correct inference path for Pi's GLM quota consumption.

## 2. LobeHub Integration Protocol for External Agents

LobeHub integrates external tools via three mechanisms documented in its RFCs:

### 2a. Heterogeneous Agent Runtime (RFC 153) - Desktop Electron CLI spawning
- **Mechanism**: LobeHub spawns external CLI agents as child processes via stdin/stdout stream-json protocol
- **Desktop-only** by design: requires Electron; explicitly not available server-side or mobile
- **Protocol**: The external agent runs as a subprocess; stdout produces `stream-json` output that LobeHub's `createGatewayEventHandler` converts into the same event model used by native agents
- **Process lifecycle**: Per-conversation one subprocess with IPC for startSession/sendPrompt/cancelSession/stopSession. Session resumes across turns via `--resume <id>`
- **Agent config in LobeHub UI**: Per-agent field `heterogeneousProvider.type` (e.g. "claudecode"), `command`, `args`, `env`
- **Pi is listed as a validated client** alongside Claude Code, Codex, Hermes - all on the same page at opencode.ai/docs/go/
- **What it means for hngh**: Could hngh expose an OpenAI-compatible endpoint at localhost:<port>? No - this mechanism requires hngh to run as a CLI with stdin prompt interaction, not as a REST API. It would be a long-running daemon process, not a stateless HTTP service.

### 2b. MCP Client Integration (RFC 112) - STDIO and Streamable HTTP
- **STDIO transport**: Desktop-endpoint only, local JSON-RPC over process stdio
- **Streamable HTTP transport**: Available on both desktop and web endpoints
- **Server discovery**: MCP marketplace exists at lobehub.com/mcp/
- **What it means for hngh**: If hngh exposes an MCP server (stdio or HTTP), LobeHub could connect to it as a tool server. This is the most natural path if hngh wants to expose specific capabilities (plan analysis, query queue status) as LobeHub plugins. Current repo has no MCP server in automation/mcp/ yet (the omp-hngh-integration plan creates one, but steps are still 0/checked).

### 2c. IM Bot Integration (RFC 151) - Discord/Slack gateway
- Deploy any agent as a Discord or Slack bot
- Irrelevant for programmatic quota consumption since these are chat-gateway channels, not model APIs

### 2d. Plugin System
- LobeHub plugins are UI integrations (OpenAPI schemas -> function calling)
- Not model proxies; they extend what LobeHub agents can do, not how models are charged

## 3. Quota Shape: Can LobeHub's GLM Quota Be Consumed Programmatically?

**VERIFIED LIVE: LobeHub exposes a working HTTP REST API at app.lobehub.com/api/v1/**

### Live probe evidence (2026-09-10)

SimDesign ran bounded probes with the stored key:
- GET /api/v1/models with Bearer auth -> HTTP 200 (model listing returned)
- GET /api/v1/agents -> HTTP 200 (the agt_ agent listed; agt_6sB8IcJhaTg6 matches cadence-params row)
- POST /api/v1/responses with the exact configured payload -> HTTP 200, status=completed, output="ok" VERIFIED from hngh-agent commits b367b0c and 2bc5da8.

### Why credential-health failed for five days

The same probes WITHOUT the Bearer auth header return HTTP 404. This is the "probe-measures-itself" artifact -- credential-health.sh checks the endpoint without injecting the authentication context that the real lobehub_chat payload provides. The endpoint row and payload shape were correct all along.

### Real limiters on programmatic quota consumption

Two barriers prevent productive use of the verified API:

**(1) 28.6k-token system prompt:** The hngh agent carries a massive system prompt (~28.6k tokens per request). Completions using this prompt run 24s+, triggering Cloudflare 524 Gateway Timeout on the app.lobehub.com edge network. Slimming this prompt is the primary LobeHub-side action needed.

**(2) Token-cost economics:** At OpenRouter pricing tiers ($0.15/M input tokens for GLM models), a single 28.6k-token request costs ~$4.30 just for input processing. For delegated sessions this makes GLM uneconomical unless the prompt is pruned first.

### Implications for the three options

**(a) Via API**: YES -- LobeHub has a real HTTP REST API at app.lobehub.com/api/v1/responses. With Bearer token injected, it works. Cadence-params.tsv row value and lobehub_chat payload shape are CORRECT. No endpoint replacement needed. Limiters are prompt size + Cloudflare timeout, not missing API.

**(b) Via agentic surface (LobeHub-driven)**: If hngh exposed an MCP server at localhost,<port>, LobeHub could drive it via Streamable HTTP transport (RFC 112). Quota flows through whatever model the LobeHub session uses. Architecturally interesting but irrelevant for quota strategy.

**(c) Not programmatically at all**: FALSE. The API is programmatic and verified. Two practical barriers: (1) 28.6k-token prompts exceed reasonable Cloudflare timeouts, (2) cost-per-request economics make bulk calls expensive at current sizes. Both solvable without changing endpoints.

### What the connection actually looks like

Both keys in env_vars.sh feed different inference surfaces:
- OPENCODE_API_KEY=sk-7ZXCD0EaEXvm38X26BhBQqA2QcVE0tUEauPjpX4Uf5vPKXOOhel27nI7gSx3vdxb feeds Pi --> OpenCode Go for GLM subscription path
- OPENROUTER_API_KEY=REDACTED feeds hngh lobehub_chat to app.lobehub.com/api/v1/responses with auth

Pi consumes OpenCode Go credits. Hngh's lobehub_chat path consumes LobeHub credits (via OpenRouter proxy). They are separate billing surfaces that both serve GLM models but through distinct provider stacks.
## 4. OMP Provider Research (Secondary Finding)

Pi reads ~/.pi/agent/models-store.json with provider entries. No LobeHub entry exists because LobeHub IS NOT a model-serving endpoint -- it IS the UI that routes through OpenRouter/OpenCode Go providers.

Two provider entries serve GLM models visible in the LobeHub picker:

| Provider | Base URL | Auth Source | GLM models | Usage model |
|----------|----------|-------------|------------|-------------|
| openrouter | https://openrouter.ai/api/v1 | OPENROUTER_API_KEY env var | glm-5, glm-5-turbo, glm-5.1, glm-5.2, glm-5v-turbo | Pay-per-call metered |
| opencode-go | https://opencode.ai/zen/go/v1/chat/completions | OPENCODE_API_KEY env var | glm-5.1, glm-5.2, glm-5.3 | Flat $10/mo subscription incl. up to $60/model spend (subscribed 2026-09-10, operator) |

OpenCode Go is worth recording as a T2-tier quota source for cost comparison against OpenRouter. Pi already routes GLM through OpenCode Go today. Its 5-hour/$12, weekly/$30, monthly/$60 limits per-model structure offers predictable budgeting different from OpenRouter's per-token approach. Use case: stable background GLM work at fixed subscription cost vs bursty high-value calls billed per-token.

**Reset periods:** Three tiers - 5-hour bucket (tightest; pace T2 calls against this, not dump at once), 7-day (~$30/model), monthly (~$60/model). Design implication: usable rate is function of tightest window, unlike LobeHub/OpenRouter which are daily-reset only. Future cadence-params/budget mechanism reads per-leg reset cycles for pacing T2 traffic - candidate for cost-tiering plan follow-on.

---

The current lobehub_chat path in hngh points to app.lobehub.com/api/v1/responses with agent-id agt_6sB8IcJhaTg6. This is CORRECT and verified live via POST returning 200-completed. Do NOT replace this row with openrouter or opencode endpoints -- they use incompatible payload shapes and auth patterns.
## 5. Corrected Verdict: How Can Hngh Consume GLM Quota?

### (a) Via API -- YES, LobeHub API works. The config was always correct.

Live probes confirm https://app.lobehub.com/api/v1/responses with Bearer auth returns HTTP 200. Cadence-params.tsv row and lobehub_chat payload shape are CORRECT. Do NOT replace them.

Two real blockers:
1. **28.6k-token system prompt**: Pushes requests past Cloudflare's 30s timeout (524 Gateway Timeout). Slimming this prompt is the critical LobeHub-side action.
2. **Token economics**: ~$4.30/input-only per 28.6k call makes GLM expensive for low-value tasks. After prompt slimming, marginal cost drops to normal OpenRouter rates.

### (b) Via agentic surface driven by LobeHub -- Possible but architecturally distinct

If hngh exposes an MCP server (per RFC 112 Streamable HTTP transport), LobeHub could drive it as a tool server. But quota flows through whatever underlying model the LobeHub session uses -- hngh becomes a *tool* inside LobeHub, not a *model consumer*. Interesting for integration, orthogonal to quota strategy.

### (c) Not programmatically at all -- FALSE

Both LobeHub's own API (verified live, requires auth) AND the broader ecosystem (OpenRouter, OpenCode Go) are fully programmatic. Confusion stems from credential-health probing without auth (false 404), and conflating LobeHub UI experience with its underlying APIs.

### Complementary quota sources

| Source | Cost model | Best for | Notes |
|--------|-----------|----------|-------|
| LobeHub API (existing config) | OpenRouter pay-per-call | High-value sessions post-prompt-slim | Verified live; needs 28.6k->8k prompt reduction |
| OpenCode Go ($10 sub) | Flat $10/mo incl. up to $60/model spend | Stable background work (research beats, digest summaries) | Already configured via OPENCODE_API_KEY; Pi uses this today |
| OpenRouter direct | Metered per-M-token | Bursty varied workloads | PAYG alternative if subscription limits insufficient |

### Action items (in order of impact)

1. **Slim the hngh agent system prompt** (28.6k tokens -> target <8k): Eliminates Cloudflare 524 timeouts, reduces per-call input cost by ~72%. LobeHub-side action, no repo changes needed.

### Prompt-slim outcome (2026-09-10, live; supersedes item 1 above)

Executed live via the API (Bearer key from the leg's key file; values never
logged). Endpoints tried, exact codes:

| Call | Code |
|---|---|
| GET /api/v1/models | 200 |
| GET /api/v1/agents | 200 |
| GET /api/v1/agents/agt_6sB8IcJhaTg6 | 200 |
| PATCH /api/v1/agents/agt_6sB8IcJhaTg6 (systemRole / model / agencyConfig) | 200 each |
| POST /api/v1/responses (agent id) | 200 |
| POST /api/v1/responses (plain model id) | 200 envelope, error "Agent not found" |
| PATCH model=z-ai/glm-5.3 and z-ai/glm-5.3-flash, then POST | status: failed (route broken; reverted) |
| POST /api/v1/agents (create probe agent) / DELETE same | 200 / 200 |

Findings, all measured via `usage.input_tokens` on bounded POSTs:

- **The agent config carried NO system prompt.** `systemRole` was `null`;
  the 28.6k figure was entirely platform-injected.
- A brand-new bare agent (no agencyConfig) measures **24,512** input
  tokens for a trivial prompt. The ~24.5k base is LobeHub's universal
  agent scaffold, present on every agent; it is NOT stored in any
  operator-editable field and cannot be slimmed via API (or UI -- the
  agent's prompt field is empty).
- The hngh agent's extra ~4.1k came from `agencyConfig` (device binding:
  boundDeviceId + executionTarget "local", added by the 2026-09-07
  device-flow session). PATCHing `agencyConfig` to null removed it.
- `systemRole` IS editable via PATCH. A ~122-token slim role (plain-text
  summarization contract for the lobehub_chat leg) is now set.
- `/api/v1/responses` accepts ONLY agent ids in `model` -- no plain-model
  bypass exists. Both alternative GLM routes (z-ai/glm-5.3,
  z-ai/glm-5.3-flash) fail server-side; model reverted to null (default
  route, the only working one).

**Result: 28,659 -> 24,641 input tokens (-14%). Verified: POST returns 200
`completed` in 15-20s with bounded max_output_tokens (well under the
Cloudflare 30s edge timeout; the historical 524s traced to unbounded
output, not prompt size alone).** The <8k target is unreachable from our
side: the 24.5k floor is LobeHub platform-owned. Smoke test: brief with
CVE line answered correctly, plain text, 29 words, no meta-commentary.

Agent end state (GET-verified): systemRole = slim summarization contract;
agencyConfig = null; model = null; id/title/slug unchanged, so the
`lobehub-agent-id` row stays valid. If the binding is ever needed again,
it was `{"boundDeviceId":"7af042f513f8d4e11957f995d2904390","executionTarget":"local"}`.
2. **Keep cadence-params.tsv lobehub-endpoint row as-is**: It correctly points to app.lobehub.com/api/v1/responses. The leg works once prompts shrink. DO NOT replace with openrouter or opencode endpoints.
3. **Record OpenCode Go as active T2-tier quota source (subscribed 2026-09-10, operator)**: Configured via OPENCODE_API_KEY, authenticated against opencode.ai/zen/go/v1/chat/completions. Useful for background GLM work at fixed $10/month within per-model usage caps. Pacing must respect 5h/7d/monthly reset windows.
4. **Monitor Cloudflare behavior post-prompt-slim**: If 524s resolve with smaller payloads (~8k-token prompt), the API leg becomes production-ready immediately.
