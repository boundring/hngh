# LOBEHUB.md -- the lobehub model-chain leg (dormant until a key path exists)

> **LIVE 2026-09-07**: inference verified at `POST https://app.lobehub.com/api/v1/responses` (OpenAI Responses shape, bearer auth; the `model` field takes a LobeHub agent id — ours: `agt_6sB8IcJhaTg6`, title 'hngh', created via API; `input` + `max_output_tokens`, read `.output_text`). See the leg header in `lib/model.sh`.

Runbook, 2026-09-07 (updated same day: kimi leg + quota-window pacing +
MODEL_PIN). The model chain in `lib/model.sh` is now: unsloth ->
openrouter -> ollama -> deck -> **kimi** -> **lobehub** -> archive-only.
The kimi and lobehub legs are the paid-quota legs: they exist for
bounded, high-value completions (research transitions, reviews) when the
free legs (unsloth, ollama, deck) are down. Telemetry counts
(`kind=model, source=kimi|lobehub`) plus quota-window pacing (below) keep
the spend visible AND evenly distributed across each UTC day.

## Quota-window pacing (both quota legs)

`quota_pace_blocked <source> <cap>` counts today's telemetry events (the
same query `remote_chat` uses) and blocks the leg when the day is being
spent faster than an even pace: `used >= cap` (hard cap) OR
`used > cap*seconds_elapsed_utc_today/86400 + 1` (soft pace, one call of
grace). A pace-blocked leg breadcrumbs "quota pace: <source> used n/cap
c -- deferring to next leg" and the chain falls through. This spreads the
daily cap across the quota window instead of front-loading it at
midnight. Env overrides: `KIMI_DAILY_CAP_CALLS` (kimi default 40, row
`kimi-daily-cap`), `LOBEHUB_DAILY_CAP_CALLS` (lobehub default 50, row
`lobehub-daily-cap`). The remote leg keeps its simple hard cap.

## MODEL_PIN doctrine

`MODEL_PIN=local` pins a call to unsloth -> ollama only (deck and the
quota legs remote/kimi/lobehub are skipped; if both fail, archive-only as
usual -- never an error). News/low-stakes callers pin local; quota legs
are reserved for bounded, specific completions. Delegated-session spend
is governed separately by the session caps. Any other MODEL_PIN value is
ignored for forward compatibility.

## The kimi quota leg (Kimi Code endpoint, 2026-09-07)

OpenAI-compatible chat-completions against the Kimi Code API
(`api.kimi.com/coding/v1`). Key resolution order (first hit wins): env
`KIMI_AI_KEY` (the operator-named K3 quota key) -> `KIMI_FOR_CODING_KEY` ->
`MOONSHOTAI_API_KEY` -> key file `~/.config/hngh/kimi-key` (mode 600
required). The key VALUE is never logged, echoed, or sent anywhere but the
Authorization header. Model gate: `KIMI_MODEL` env -> `kimi-model` tsv row
(empty = skipped fail-closed). Endpoint: `KIMI_URL` env -> `kimi-endpoint`
row (default `https://api.kimi.com/coding/v1/chat/completions`). Body is
lean (model/messages/max_tokens only, `_kimi_body`): the coding gateway
HTTP-400s on `temperature`. Full probe matrix, gotchas, and the open
operator question live in `docs/KIMI-QUOTA.md`.

Discovery findings, verified live 2026-09-07 (key values never printed):

- `MOONSHOTAI_API_KEY` validates on `api.moonshot.ai` (`GET /v1/models`
  -> HTTP 200). Model ids offered: `kimi-k2.6`, `kimi-k2.7-code`. **No
  literal "K3" id exists on the platform API** -- `kimi-k2.6` is the
  general model in use.
- The same account currently returns HTTP 429
  (`exceeded_current_quota_error`, "insufficient balance") on chat
  completions: the key is armed but the account needs a recharge/plan.
  Until then every kimi attempt 429s, breadcrumbs, and falls through
  fail-closed -- exactly the designed behavior.
- `KIMI_AI_KEY` / `KIMI_FOR_CODING_KEY`: 401 on `api.moonshot.ai` AND
  `api.moonshot.cn` (the earlier notes' "401 there" meant .ai only; the
  CN platform rejects them identically) -- but both validate on
  `api.kimi.com/coding/v1` (models 200: `kimi-for-coding`,
  `kimi-for-coding-highspeed`, `k3-256k`, `k3`) and complete there.
  **The kimi leg was re-landed on this endpoint the same day**; see
  `docs/KIMI-QUOTA.md` for the full matrix. Live end-to-end proof:
  `kimi_chat` with `KIMI_MODEL=k3-256k` returned "MATRIX-OK" (exit 0).

Operator morning step (activation): create/charge the Moonshot platform
key, then either rely on the session env (`MOONSHOTAI_API_KEY`) or drop
it to `~/.config/hngh/kimi-key` with mode 600
(`install -m 600 /dev/null ~/.config/hngh/kimi-key` then paste). The
`kimi-model` tsv row is owned by the cadence-tuning lane; until that
lane's commit lands, `KIMI_MODEL=kimi-k2.6` in `config.env` is the
stopgap (remove it when the row lands -- env wins over the row).

## Status: DORMANT -- no documented key path

Honest statement, verified 2026-09-07 against the fetched docs:

- Lobehub's documented programmatic surfaces are **OAuth Cloud tokens**
  (RFC 8414/9728 discovery at `/.well-known/oauth-authorization-server`),
  a **WebMCP endpoint** at `/api/mcp`, and the official **CLI**
  (`@lobehub/cli`, `lh` login).
- An OpenAI-compatible inference endpoint for premium quota models is
  **NOT documented**. Their published openapi.json covers helper
  endpoints only. The leg's default endpoint
  (`https://api.lobehub.com/v1/chat/completions`, cadence-params row
  `lobehub-endpoint`) is the OpenAI-shaped *guess*; it has never been
  confirmed by any doc.
- Therefore the leg lands **machinery-ready but dormant**. If the
  morning's verification finds a bearer-accepted inference endpoint, the
  leg flips live with zero further code. If not, the leg stays dormant
  and the real Lobehub integration is the WebMCP/notification route
  (separate work item).

## Activation runbook (operator, one session)

Verified mechanics, 2026-09-07 (discovery + @lobehub/cli 0.0.52 bundle
read; token values never printed). Three viable paths, best first:

**Path A -- one-command device flow (no CLI needed):**
`scripts/lobehub-oauth-login.sh`
It does the OAuth Device Code Flow machine-side (POST
`https://app.lobehub.com/oidc/device/auth`, public client
`lobehub-cli`, resource `urn:lobehub:chat`, scopes
`openid profile email offline_access`), prints + opens the
verification URL, polls `/oidc/token`, and writes the access token to
`~/.config/hngh/lobehub-key` (mode 600). You approve in the browser;
the token VALUE is never echoed.

**Path B -- if you already ran `lh login`:**
`scripts/lobehub-oauth-login.sh --from-cli`
Decrypts `~/.lobehub/credentials.json` (AES-256-GCM, key derived
machine-locally from hostname+username) and writes the same key file.
`lh` is installed (`npm -g @lobehub/cli`, v0.0.52); `lh login` is the
same device flow in the CLI's own store.

**Path C -- manual fallback (blocker: the discovery document's
`registration_endpoint` is session-gated -- POST /oauth/register 302s
to /signin, and no keyless public client_id is published for the web
app):** log into lobehub.com, create a Cloud token in its UI, then
`install -m 600 /dev/null ~/.config/hngh/lobehub-key` and paste.

Then, regardless of path:

1. `scripts/lobehub-verify.sh` -- bearer-probes the account surface
   and the OpenAI-shaped inference candidates; prints FOUND (with the
   endpoint + model list) or "leg stays dormant". Exit 0 always.
2. If FOUND: fill the Inventory row `lobehub-model` in
   `cadence-params.tsv` (by hand or request) with a model id from the
   model list; the leg goes live on the next model_call. Pacing/cap
   rows already exist.
3. If not exposed: leave or delete the key file; the leg stays dormant
   behind the gates and the WebMCP route is the follow-on.

### Keyless surface probes (2026-09-07, read-only, no key sent)

| Surface | Status | One real line |
| --- | --- | --- |
| `https://lobehub.com/.well-known/oauth-authorization-server` | HTTP 200 | `"authorization_endpoint":"https://app.lobehub.com/oauth/authorize"` (issuer `app.lobehub.com`, S256 PKCE) |
| `https://lobehub.com/api/mcp` | HTTP 200 | `"WebMCP transport endpoint for LobeHub discovery metadata and UI resources."` (protocolVersion 2025-03-26) |
| `https://api.lobehub.com/v1/chat/completions` (the leg's default endpoint) | HTTP 404 | `DEPLOYMENT_NOT_FOUND` (Vercel) -- **api.lobehub.com is not a live host** |
| `https://api.lobehub.com/.well-known/oauth-authorization-server`, `/api/mcp` | HTTP 404 | same `DEPLOYMENT_NOT_FOUND` |

### WebMCP JSON-RPC verification (2026-09-07, second pass, no auth)

Full handshake against `https://lobehub.com/api/mcp` with JSON-RPC bodies
(no Authorization header): `initialize` (protocolVersion 2025-03-26) ->
200, `serverInfo: {"name":"LobeHub WebMCP","version":"1.0.0"}`;
`tools/list` -> 200, one tool `lobehub_get_onboarding_links`;
`resources/list` -> 200, `ui://lobehub/onboarding` + `ui://lobehub/pricing`;
`notifications/initialized` -> 200 with error -32601 (stateless: supported
methods are initialize / resources-list / resources-read / tools-list /
tools-call). Verdict: **keyless is definitive** for WebMCP, but it is an
onboarding/discovery surface, not inference or account management. Full
study: hngh `docs/research/2026-09-07-lobehub-integration-surface.md`
(also covers `/api/agent-readiness`, the market.lobehub.com MCP
marketplace, the desktop app's loopback-only port 33250 with no
management API, and the Android distribution/channels picture).

Conclusion unchanged: the OpenAI-shaped inference endpoint remains a
guess, and its default host is dead. The leg stays dormant behind the
key+model gates; env `LOBEHUB_KEY` may arm the key half if the operator
ever obtains a Lobehub Cloud token, but a working endpoint URL
(`LOBEHUB_URL` / `lobehub-endpoint` row) would also be required.

## Lobehub AppImage (machine-side install, 2026-09-07)

`~/Downloads/LobeHub-2.2.16.AppImage` copied (originals preserved) to
`~/Applications/LobeHub-2.2.16.AppImage`, chmod +x, **not launched** --
the GUI is the operator's. No agent session ever starts it.

## Cost / routing intent

The chain prefers free local capacity first (unsloth -> ollama -> deck).
Kimi and Lobehub are the paid-late legs: they fire only after every free
leg fails, paced across the UTC day by `quota_pace_blocked`, each call
emitting a telemetry row so the nightly cost-and-route readout sees it.
Env overrides: `LOBEHUB_URL` (endpoint), `LOBEHUB_KEY_FILE` (token
path), `LOBEHUB_DAILY_CAP_CALLS` (cap). The model row has no env
override by design: the operator names the model in the Inventory.

## Tests

`tests/test-model-lobehub-leg.sh` (wired into `make test`) proves all
paths for lobehub. `tests/test-model-kimi-leg.sh` (also in `make test`)
proves the kimi leg plus the shared machinery: no key/no model -> skip;
env key and mode-600 file key + model + stub -> `MODEL_USED=kimi:<model>`
+ one telemetry row; mode-644 key file -> refused with breadcrumb;
pace-blocked (above the pace line, below cap) and hard-capped -> kimi
skipped, lobehub answers; helper boundaries; `MODEL_PIN=local` -> quota
stubs never hit, unsloth answers; dead endpoint -> HTTP 000 breadcrumb +
fall-through. Live-path smoke (manual, bounded): `KIMI_MODEL=kimi-k2.6
MAX_TOKENS`-style one-shot `model_call` with max_tokens 32 and read
`tmp-modelused.txt`.
